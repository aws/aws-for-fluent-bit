package main

import (
	"encoding/json"
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

// static file path
const ConfigFileFolderPath = "init_process_fluent-bit_s3_config_files"
const MainConfigFilePath = "init_process_fluent-bit.conf"
const OriginalMainConfigFilePath = "/fluent-bit/etc/fluent-bit.conf"
const InvokerFilePath = "invoker.sh"

// default Fluent Bit command
var FluentBitCommand = "exec /fluent-bit/bin/fluent-bit -e /fluent-bit/firehose.so -e /fluent-bit/cloudwatch.so -e /fluent-bit/kinesis.so"

// global s3 client and flag
var s3Client *s3.S3
var exists3Client bool = false

// global ecs metadata region
var metadataReigon string = ""

// set error log format
func setErrorLog() {
	log.SetFlags(log.Ldate | log.Ltime | log.Lshortfile)
	log.SetPrefix("FluentBit Init Process -> ")
}

// create the invoker.sh
// which will declare ECS Task Metadata as environment variables
// and finally invoke Fluent Bit
func createInvokerFile(filePath string) {
	invokerFile, err := os.Create(filePath)
	if err != nil {
		log.Println(err)
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

// get ECS Task Metadata via endpoint V4
func getECSTaskMetadata() ECSTaskMetadata {
	var metadata ECSTaskMetadata

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

	err = json.Unmarshal(response, &metadata)
	if err != nil {
		log.Println(err)
		log.Panicln("failed to unmarshal ECS metadata")
	}

	ARN, err := arn.Parse(metadata.ECS_TASK_ARN)
	if err != nil {
		log.Println(err)
		log.Panicln("failed to parse ECS TaskARN")
	}

	resourceID := strings.Split(ARN.Resource, "/")
	taskID := resourceID[len(resourceID)-1]
	metadata.ECS_TASK_ID = taskID
	metadata.AWS_REGION = ARN.Region
	metadata.ECS_TASK_DEFINITION = metadata.ECS_FAMILY + ":" + metadata.ECS_REVISION

	return metadata
}

// set ECS Task Metadata as environment variables in the invoker.sh
func setECSTaskMetadataAsEnvVar(metadata ECSTaskMetadata, filePath string) {
	t := reflect.TypeOf(metadata)
	v := reflect.ValueOf(metadata)

	initProcessEntrypointFile, err := os.OpenFile(filePath, os.O_APPEND|os.O_WRONLY, 0777)
	if err != nil {
		log.Println(err)
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
			log.Println(err)
			log.Fatalf("Cannot write %s in init process entrypoint file\n", writeContent[:len(writeContent)-2])
		}
	}
}

// create a new main config file
func createMainConfigFile(filePath string) {
	mainConfigFile, err := os.Create(filePath)
	if err != nil {
		log.Println(err)
		log.Fatalln("Cannot create main config file")
	}
	defer mainConfigFile.Close()
}

// add @INCLUDE original main config file to the new main config file
func includeOriginalMainConfigFile(mainConfigFilePath, originalMainConfigFilePath string) {
	mainConfigFile, err := os.OpenFile(mainConfigFilePath, os.O_APPEND|os.O_WRONLY, 0777)
	if err != nil {
		log.Println(err)
		log.Fatalf("Unable to read main config file: %s\n", mainConfigFilePath)
	}
	defer mainConfigFile.Close()

	writeContent := "@INCLUDE " + originalMainConfigFilePath + "\n"
	_, err = mainConfigFile.WriteString(writeContent)
	if err != nil {
		log.Println(err)
		log.Fatalf("Cannot write %s in main config file: %s\n", writeContent[:len(writeContent)-2], mainConfigFilePath)
	}
}

// create Fluent Bit command to use new main config file
func createCommand(command *string, filePath string) {
	*command = *command + " -c /" + filePath
}

// create a folder to store S3 config files user specified
func createS3ConfigFileFolder(folderPath string) {
	os.Mkdir(folderPath, os.ModePerm)
}

// get our built in config file or files from s3
// process built-in config files directly
// add S3 config files to folder "init_process_fluent-bit_s3_config_files"
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
			processBuiltInConfigFile(envValue)
		}
	}
}

// process built-in config files
func processBuiltInConfigFile(path string) {
	content_b, err := ioutil.ReadFile(path)
	if err != nil {
		log.Println(err)
		log.Fatalf("Cannot open file: %s\n", path)
	}
	content := string(content_b)
	if strings.Contains(content, "[PARSER]") {
		// this is a parser config file, change command
		updateCommand(path)
	} else {
		// this is not a parser config file. @INCLUDE
		writeInclude(path, MainConfigFilePath)
	}
}

// download S3 config file to S3 config file folder
func getS3ConfigFile(arn string) {
	if !exists3Client {
		createS3Client()
	}

	//e.g. "arn:aws:s3:::ygloa-bucket/s3_parser.conf"
	arnBucketFile := arn[13:]
	bucketAndFile := strings.SplitN(arnBucketFile, "/", 2)
	if len(bucketAndFile) != 2 {
		log.Fatalf("Unrecognizable arn: %s\n", arn)
	}

	bucketName := bucketAndFile[0]
	s3FilePath := bucketAndFile[1]

	// get bucket region
	input := &s3.GetBucketLocationInput{
		Bucket: aws.String(bucketName),
	}

	output, err := s3Client.GetBucketLocation(input)
	if err != nil {
		log.Println(bucketName + ":" + s3FilePath)
		log.Println(err)
		log.Println("Cannot get bucket region")
	}

	bucketRegion := aws.StringValue(output.LocationConstraint)
	// Buckets in Region us-east-1 have a LocationConstraint of null.
	// https://docs.aws.amazon.com/sdk-for-go/api/service/s3/#GetBucketLocationOutput
	if bucketRegion == "" {
		bucketRegion = "us-east-1"
	}

	// create downloader
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(bucketRegion)},
	)
	if err != nil {
		log.Println(err)
		log.Fatalln("Cannot creat a new session")
	}

	// need to specify session region!
	s3Downloader := s3manager.NewDownloader(sess)

	// download file and store
	s3FileName := strings.SplitN(s3FilePath, "/", -1)
	fileFromS3, err := os.Create(ConfigFileFolderPath + "/" + s3FileName[len(s3FileName)-1])
	if err != nil {
		log.Println(err)
		log.Fatalln("Cannot creat s3 config file to store config info")
	}
	defer fileFromS3.Close()

	_, err = s3Downloader.Download(fileFromS3,
		&s3.GetObjectInput{
			Bucket: aws.String(bucketName),
			Key:    aws.String(s3FilePath),
		})
	if err != nil {
		log.Println(err)
		log.Fatalf("Cannot download %s from s3\n", s3FileName)
	}
}

// create a S3 client as the global S3 client for reuse
func createS3Client() {
	region := "us-east-1"
	if metadataReigon != "" {
		region = metadataReigon
	}
	s3Client = s3.New(session.Must(session.NewSession(&aws.Config{
		// if not specify region here, missingregion error will raise when get bucket location
		Region: aws.String(region),
	})))

	exists3Client = true
}

// process S3 config files user specified.
func processS3ConfigFiles(folderPath string) {
	fileInfos, err := ioutil.ReadDir(folderPath)
	if err != nil {
		log.Println(err)
		log.Fatalf("Unable to read config files in %s folder\n", folderPath)
	}

	for _, file := range fileInfos {
		content_b, err := ioutil.ReadFile(folderPath + "/" + file.Name())
		if err != nil {
			log.Println(err)
			log.Fatalf("Cannot open file: %s\n", folderPath+"/"+file.Name())
		}
		content := string(content_b)
		if strings.Contains(content, "[PARSER]") {
			// this is a parser config file. change command
			updateCommand("/" + folderPath + "/" + file.Name())
		} else {
			// this is not a parser config file. @INCLUDE
			writeInclude("/"+folderPath+"/"+file.Name(), MainConfigFilePath)
		}
	}
}

// add @INCLUDE in main config file to include all customer specified config files
func writeInclude(configFilePath, mainConfigFilePath string) {
	mainConfigFile, err := os.OpenFile(mainConfigFilePath, os.O_APPEND|os.O_WRONLY, 0777)
	if err != nil {
		log.Println(err)
		log.Fatalf("Unable to read main config file: %s\n", mainConfigFilePath)
	}
	defer mainConfigFile.Close()

	writeContent := "@INCLUDE " + configFilePath + "\n"
	_, err = mainConfigFile.WriteString(writeContent)
	if err != nil {
		log.Println(err)
		log.Fatalf("Cannot write %s in main config file: %s\n", writeContent[:len(writeContent)-2], mainConfigFilePath)
	}
}

// change the cammand if needed.
// add modified command to the init_process_entrypoint.sh
func updateCommand(parserFilePath string) {
	FluentBitCommand = FluentBitCommand + " -R " + parserFilePath
	log.Println("Command is change to -> " + FluentBitCommand)
}

// create a init_process_entrypoint.sh
// which will declare ECS Task Metadata as environment variables
// and finally invoke Fluent Bit
func modifyInvokerFile(filePath string) {
	invokerFile, err := os.OpenFile(filePath, os.O_APPEND|os.O_WRONLY, 0777)
	if err != nil {
		log.Println(err)
		log.Fatalf("Unable to read init process entrypoint file: %s\n", InvokerFilePath)
	}
	defer invokerFile.Close()

	_, err = invokerFile.WriteString(FluentBitCommand)
	if err != nil {
		log.Println(err)
		log.Fatalf("Cannot write %s in init process entrypoint file\n", FluentBitCommand)
	}
}

func main() {

	// set init process err log
	setErrorLog()

	// create the invoker.sh
	// which will declare ECS Task Metadata as environment variables
	// and finally invoke Fluent Bit
	createInvokerFile(InvokerFilePath)

	// get ECS Task Metadata and set the region for S3 client
	metadata := getECSTaskMetadata()
	metadataReigon = reflect.ValueOf(metadata).Field(0).Interface().(string)

	// set ECS Task Metada as env vars in the invoker.sh
	setECSTaskMetadataAsEnvVar(metadata, InvokerFilePath)

	// create main config file which will be used invoke Fluent Bit
	createMainConfigFile(MainConfigFilePath)

	// use @INCLUDE to add original main config file
	includeOriginalMainConfigFile(MainConfigFilePath, OriginalMainConfigFilePath)

	// create Fluent Bit command to use new main config file
	createCommand(&FluentBitCommand, MainConfigFilePath)

	// create a S3 config files folder
	createS3ConfigFileFolder(ConfigFileFolderPath)

	// get our built in config file or files from s3
	// process built-in config files directly
	// add S3 config files to folder "init_process_fluent-bit_s3_config_files"
	getAllConfigFiles()

	// process all config files in config file folder, add @INCLUDE in main config file and change command
	processS3ConfigFiles(ConfigFileFolderPath)

	// modify invoker.sh, invoke fluent bit
	modifyInvokerFile(InvokerFilePath)
}

