package main

//TODO:
//all err log
//all permission like 666/777
//mutiple parser, how to change command?

import (
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"reflect"
	"regexp"
	"strings"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/arn"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
)

//Static file path
const ConfigFileFolderPath = "init_process_fluent-bit_config_files"
const MainConfigFilePath = "init_process_fluent-bit.conf"
const OriginalMainConfigFilePath = "/fluent-bit/etc/fluent-bit.conf"
const InvokerFilePath = "invoker.sh"

//default command
var FluentBitCommand = "exec /fluent-bit/bin/fluent-bit -e /fluent-bit/firehose.so -e /fluent-bit/cloudwatch.so -e /fluent-bit/kinesis.so"

//global s3 client
var s3er *s3.S3
var existS3er bool = false

//set error log format
func setErrorLog() {
	log.SetFlags(log.Ldate | log.Ltime | log.Lshortfile)
	log.SetPrefix("FluentBit Init Process-> ")
}

//create a invoker.sh
//which will declare ECS Task Metadata as environment variables
//and finally invoke Fluent Bit
func createInvokerFile(filePath string) {
	invokerFile, err := os.Create(filePath)
	if err != nil {
		fmt.Println(err)
		log.Fatalln("Cannot create fluent bit invoker file")
	}
	defer invokerFile.Close()
}

type ECSTaskMetadata struct {
	AWS_REGION          string `json:"AWSRegion"`
	ECS_CLUSTER         string `json:"Cluster"`
	ECS_TASK_ARN        string `json:"TaskARN"`
	ECS_TASK_ID         string `json:"TaskID"`
	ECS_FAMILY          string `json:"Family"`
	ECS_LAUNCHTYPE      string `json:"LaunchType"` //If container agent is under version 1.45.0, this env var will be an empty string
	ECS_REVISION        string `json:"Revision"`
	ECS_TASK_DEFINITION string `json:"TaskDefinition"`
}

//get ECS Task Metadata via endpoint V4
func getECSTaskMetadata() ECSTaskMetadata {
	var ecs_task_metadata ECSTaskMetadata

	ecsTaskMetadataEndpointV4 := os.Getenv("ECS_CONTAINER_METADATA_URI_V4")
	if ecsTaskMetadataEndpointV4 == "" {
		log.Panicln("Unable to get ECS Metadata")
	}

	res, err := http.Get(ecsTaskMetadataEndpointV4 + "/task")
	if err != nil {
		log.Panicln("failed to get ECS Metadata via HTTP Get")
	}

	response, err := ioutil.ReadAll(res.Body)
	if err != nil {
		log.Panicln("failed to read response")
	}
	res.Body.Close()

	err = json.Unmarshal(response, &ecs_task_metadata)
	if err != nil {
		fmt.Println(err)
		log.Panicln("failed to unmarshal ECS metadata")
	}

	ARN, err := arn.Parse(ecs_task_metadata.ECS_TASK_ARN)
	if err != nil {
		fmt.Println(err)
		log.Panicln("failed to parse ECS TaskARN")
	}

	resourceID := strings.Split(ARN.Resource, "/")
	taskID := resourceID[len(resourceID)-1]
	ecs_task_metadata.ECS_TASK_ID = taskID
	ecs_task_metadata.AWS_REGION = ARN.Region
	ecs_task_metadata.ECS_TASK_DEFINITION = ecs_task_metadata.ECS_FAMILY + ":" + ecs_task_metadata.ECS_REVISION

	return ecs_task_metadata
}

//set ECS Task Metadata as environment variables
func setECSTaskMetadataAsEnvVar(ecs_task_metadata ECSTaskMetadata, filePath string) {
	t := reflect.TypeOf(ecs_task_metadata)
	v := reflect.ValueOf(ecs_task_metadata)

	initProcessEntrypointFile, err := os.OpenFile(filePath, os.O_APPEND|os.O_WRONLY, 0777)
	if err != nil {
		fmt.Println(err)
		log.Fatalf("Unable to read init process entrypoint file: %s\n", filePath)
	}
	defer initProcessEntrypointFile.Close()

	for i := 0; i < t.NumField(); i++ {
		if v.Field(i).Interface().(string) == "" {
			continue
		}
		writeContent := "export " + t.Field(i).Name + "=" + v.Field(i).Interface().(string) + "\n"
		_, err = initProcessEntrypointFile.WriteString(writeContent)
		if err != nil {
			fmt.Println(err)
			log.Fatalf("Cannot write %s in init process entrypoint file\n", writeContent[:len(writeContent)-2])
		}
	}
}

//create a new main config file
func createMainConfigFile(filePath string) {
	mainConfigFile, err := os.Create(filePath)
	if err != nil {
		fmt.Println(err)
		log.Fatalln("Cannot create main config file")
	}
	defer mainConfigFile.Close()
}

//add @INCLUDE original main config file to the new main config file
func includeOriginalMainConfigFile(mainConfigFilePath, originalMainConfigFilePath string) {
	mainConfigFile, err := os.OpenFile(mainConfigFilePath, os.O_APPEND|os.O_WRONLY, 0777)
	if err != nil {
		fmt.Println(err)
		log.Fatalf("Unable to read main config file: %s\n", mainConfigFilePath)
	}
	defer mainConfigFile.Close()

	writeContent := "@INCLUDE " + originalMainConfigFilePath + "\n"
	_, err = mainConfigFile.WriteString(writeContent)
	if err != nil {
		fmt.Println(err)
		log.Fatalf("Cannot write %s in main config file: %s\n", writeContent[:len(writeContent)-2], mainConfigFilePath)
	}
}

//create fluent bit command to use new main config file
func createCommand(command *string, filePath string) {
	*command = *command + " -c /" + filePath
}

//create a folder to store config files user specified
func createConfigFileFolder(folderPath string) {
	os.Mkdir(folderPath, os.ModePerm)
}

//get config files user specified according to environment variables
func getAllConfigFiles() {

	//get all env vars
	envs := os.Environ()
	//find all env vars match specified prefix
	for _, env := range envs {
		var envKey string
		var envValue string
		env_kv := strings.SplitN(env, "=", 2)
		if len(env_kv) != 2 {
			log.Printf("Unrecognizable environment variables: %s\n", env)
			continue
		}

		envKey = string(env_kv[0])
		envValue = string(env_kv[1])

		matched_s3, _ := regexp.MatchString("aws_fluent_bit_s3_", envKey)
		matched_file, _ := regexp.MatchString("aws_fluent_bit_file_", envKey)
		//if this env var's value is an arn
		if matched_s3 {
			getS3ConfigFile(envValue)
		}
		//if this env var's value is a path of our built-in config file
		if matched_file {
			getBuiltInConfigFile(envValue)
		}
	}
}

//copy built-in config file to config file folder
func getBuiltInConfigFile(path string) {

	fileName := strings.SplitN(path, "/", -1)

	src, err := os.Open(path[1:]) //remove first "/"
	if err != nil {
		fmt.Println(err)
		log.Fatalf("Cannot find built-in config file: %s\n", path[1:])
	}
	defer src.Close()

	dstPath := ConfigFileFolderPath + "/" + fileName[len(fileName)-1]
	dst, err := os.Create(dstPath)
	if err != nil {
		fmt.Println(err)
		log.Fatalln("Cannot creat config file folder")
	}
	defer dst.Close()

	io.Copy(dst, src)
}

//download S3 config file to config file folder
func getS3ConfigFile(arn string) {
	if !existS3er {
		// creat global s3 client
		// s3er = s3.New(session.Must(session.NewSession()))
		s3er = s3.New(session.Must(session.NewSession(&aws.Config{
			//if not specify region here, missingregion error will raise when get bucket location
			//can be any region
			Region: aws.String("us-east-2"),
		})))

		existS3er = true
	}

	//e.g. "arn:aws:s3:::ygloa-bucket/s3_parser.conf"
	arn_bucket_file := arn[13:]
	bucket_and_file := strings.SplitN(arn_bucket_file, "/", 2)
	if len(bucket_and_file) != 2 {
		log.Fatalf("Unrecognizable arn: %s\n", arn)
	}

	bucket_name := bucket_and_file[0]
	s3_file_path := bucket_and_file[1]

	// get bucket region
	input := &s3.GetBucketLocationInput{
		Bucket: aws.String(bucket_name),
	}

	output, err := s3er.GetBucketLocation(input)
	if err != nil {
		fmt.Println(bucket_name + ":" + s3_file_path)
		fmt.Println(err)
		// log.Fatalln("Cannot get bucket region")
		fmt.Println("Cannot get bucket region")
	}

	bucket_region := aws.StringValue(output.LocationConstraint)
	// Buckets in Region us-east-1 have a LocationConstraint of null.
	// https://docs.aws.amazon.com/sdk-for-go/api/service/s3/#GetBucketLocationOutput
	if bucket_region == "" {
		bucket_region = "us-east-1"
	}

	//create downloader
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(bucket_region)},
	)
	if err != nil {
		fmt.Println(err)
		log.Fatalln("Cannot creat a new session")
	}
	// need to specify session region!
	// sess := session.Must(session.NewSession())
	// fmt.Println(*sess.Config.Region)
	s3_downloader := s3manager.NewDownloader(sess)

	//download file and store
	s3_file_name := strings.SplitN(s3_file_path, "/", -1)
	file_from_s3, err := os.Create(ConfigFileFolderPath + "/" + s3_file_name[len(s3_file_name)-1])
	if err != nil {
		fmt.Println(err)
		log.Fatalln("Cannot creat s3 config file to store config info")
	}
	defer file_from_s3.Close()

	_, err = s3_downloader.Download(file_from_s3,
		&s3.GetObjectInput{
			Bucket: aws.String(bucket_name),
			Key:    aws.String(s3_file_path),
		})
	if err != nil {
		fmt.Println(err)
		log.Fatalf("Cannot download %s from s3\n", s3_file_name)
	}
}

//process config files user specified.
func processAllConfigFiles(folderPath string) {
	fileInfos, err := ioutil.ReadDir(folderPath)
	if err != nil {
		fmt.Println(err)
		log.Fatalf("Unable to read config files in %s folder\n", folderPath)
	}

	for _, file := range fileInfos {
		content_b, err := ioutil.ReadFile(folderPath + "/" + file.Name())
		if err != nil {
			fmt.Println(err)
			log.Fatalf("Cannot open file: %s\n", folderPath+"/"+file.Name())
		}
		content := string(content_b)
		if strings.Contains(content, "[PARSER]") {
			// this is a parser config file. change command
			changeCommandToAddR("/" + folderPath + "/" + file.Name())
		} else {
			// this is not a parser config file. @INCLUDE
			// writeInclude("/"+folderPath+"/"+file.Name(), MainConfigFilePath)
			writeInclude("/"+folderPath+"/"+file.Name(), MainConfigFilePath)
		}
	}
}

//add @INCLUDE in main config file to include all customer specified config files
func writeInclude(configFilePath, mainConfigFilePath string) {
	mainConfigFile, err := os.OpenFile(mainConfigFilePath, os.O_APPEND|os.O_WRONLY, 0777)
	if err != nil {
		fmt.Println(err)
		log.Fatalf("Unable to read main config file: %s\n", mainConfigFilePath)
	}
	defer mainConfigFile.Close()

	writeContent := "@INCLUDE " + configFilePath + "\n"
	_, err = mainConfigFile.WriteString(writeContent)
	if err != nil {
		fmt.Println(err)
		log.Fatalf("Cannot write %s in main config file: %s\n", writeContent[:len(writeContent)-2], mainConfigFilePath)
	}
}

//change the cammand if needed.
//add modified command to the init_process_entrypoint.sh
func changeCommandToAddR(parserFilePath string) {
	FluentBitCommand = FluentBitCommand + " -R " + parserFilePath
	log.Println("Command is change to ---> " + FluentBitCommand)
}

//create a init_process_entrypoint.sh
//which will declare ECS Task Metadata as environment variables
//and finally invoke Fluent Bit
func modifyInvokerFile(filePath string) {
	invokerFile, err := os.OpenFile(filePath, os.O_APPEND|os.O_WRONLY, 0777)
	if err != nil {
		fmt.Println(err)
		log.Fatalf("Unable to read init process entrypoint file: %s\n", InvokerFilePath)
	}
	defer invokerFile.Close()

	_, err = invokerFile.WriteString(FluentBitCommand)
	if err != nil {
		fmt.Println(err)
		log.Fatalf("Cannot write %s in init process entrypoint file\n", FluentBitCommand)
	}
}

func main() {

	//set log
	setErrorLog()

	//create a invoker.sh
	//which will declare ECS Task Metadata as environment variables
	//and finally invoke Fluent Bit
	createInvokerFile(InvokerFilePath)

	// get ECS Task Metadata
	ecs_task_metadata := getECSTaskMetadata()
	log.Println("MetaData =================================")
	log.Println(ecs_task_metadata)

	// set ECS Task Metada as env vars
	setECSTaskMetadataAsEnvVar(ecs_task_metadata, InvokerFilePath)

	//create main config file which will be used invoke Fluent Bit
	createMainConfigFile(MainConfigFilePath)

	//include original main config file
	includeOriginalMainConfigFile(MainConfigFilePath, OriginalMainConfigFilePath)

	//create fluent bit command to use new main config file
	createCommand(&FluentBitCommand, MainConfigFilePath)

	//create a config files folder
	createConfigFileFolder(ConfigFileFolderPath)

	//get our built in config file or files from s3, add them to folder "fluentbit_config_files"
	getAllConfigFiles()

	//process all config files in config file folder, add @INCLUDE in main config file and change command
	processAllConfigFiles(ConfigFileFolderPath)

	// modify invoker.sh, invoke fluent bit
	modifyInvokerFile(InvokerFilePath)
}
