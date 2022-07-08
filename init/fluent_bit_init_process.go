package main

import (
	"encoding/json"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"strings"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/arn"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
	"github.com/sirupsen/logrus"
)

// static paths
const (
	s3FileDirectoryPath    = "/init/fluent-bit-init-s3-files/"
	mainConfigFile         = "/init/fluent-bit-init.conf"
	originalMainConfigFile = "/fluent-bit/etc/fluent-bit.conf"
	invokeFile             = "/init/invoke_fluent_bit.sh"
)

var (
	// default Fluent Bit command
	baseCommand = "exec /fluent-bit/bin/fluent-bit -e /fluent-bit/firehose.so -e /fluent-bit/cloudwatch.so -e /fluent-bit/kinesis.so"

	// global s3 client and flag
	s3Client        *s3.S3
	s3ClientCreated bool = false

	// global ecs metadata region
	metadataRegion string = ""
)

// HTTPClient interface
type HTTPClient interface {
	Get(url string) (*http.Response, error)
}

// S3Downloader interface
type S3Downloader interface {
	Download(w io.WriterAt, input *s3.GetObjectInput, options ...func(*s3manager.Downloader)) (int64, error)
}

// all values in the structure are empty strings by default
type ECSTaskMetadata struct {
	AWS_REGION          string `json:"AWSRegion"`
	ECS_CLUSTER         string `json:"Cluster"` // Cluster name
	ECS_TASK_ARN        string `json:"TaskARN"`
	ECS_TASK_ID         string `json:"TaskID"`
	ECS_FAMILY          string `json:"Family"`
	ECS_LAUNCH_TYPE     string `json:"LaunchType"`     // Task launch type will be an empty string if container agent is under version 1.45.0
	ECS_REVISION        string `json:"Revision"`       // Revision number
	ECS_TASK_DEFINITION string `json:"TaskDefinition"` // TaskDefinition = "family:revision"
}

// get ECS Task Metadata via endpoint V4
func getECSTaskMetadata(httpClient HTTPClient) ECSTaskMetadata {
	var metadata ECSTaskMetadata

	ecsTaskMetadataEndpointV4 := os.Getenv("ECS_CONTAINER_METADATA_URI_V4")
	if ecsTaskMetadataEndpointV4 == "" {
		logrus.Warnln("[FluentBit Init Process] Unable to get ECS Metadata, ignore this warning if not running on ECS")
		return metadata
	}

	res, err := httpClient.Get(ecsTaskMetadataEndpointV4 + "/task")
	if err != nil {
		logrus.Fatalf("[FluentBit Init Process] Failed to get ECS Metadata via HTTP Get: %s\n", err)
	}

	response, err := ioutil.ReadAll(res.Body)
	if err != nil {
		logrus.Fatalf("[FluentBit Init Process] Failed to read ECS Metadata from HTTP response: %s\n", err)
	}
	res.Body.Close()

	err = json.Unmarshal(response, &metadata)
	if err != nil {
		logrus.Fatalf("[FluentBit Init Process] Failed to unmarshal ECS metadata: %s\n", err)
	}

	arn, err := arn.Parse(metadata.ECS_TASK_ARN)
	if err != nil {
		logrus.Fatalf("[FluentBit Init Process] Failed to parse ECS TaskARN: %s\n", err)
	}

	resourceID := strings.Split(arn.Resource, "/")
	taskID := resourceID[len(resourceID)-1]
	metadata.ECS_TASK_ID = taskID
	metadata.AWS_REGION = arn.Region
	metadata.ECS_TASK_DEFINITION = metadata.ECS_FAMILY + ":" + metadata.ECS_REVISION

	// set global ecs metadata region for S3 client
	metadataRegion = reflect.ValueOf(metadata).Field(0).Interface().(string)

	return metadata
}

// set ECS Task Metadata as environment variables in the invoke_fluent_bit.sh
func setECSTaskMetadata(metadata ECSTaskMetadata, filePath string) {
	invokeFile := openFile(filePath)
	defer invokeFile.Close()

	// set the FLB_AWS_USER_AGENT env var as "init" to get the image usage
	initUsage := "export FLB_AWS_USER_AGENT=init\n"
	_, err := invokeFile.WriteString(initUsage)
	if err != nil {
		logrus.Errorln(err)
		logrus.Warnf("[FluentBit Init Process] Cannot write %s in the invoke_fluent_bit.sh\n", initUsage[:len(initUsage)-2])
	}

	t := reflect.TypeOf(metadata)
	v := reflect.ValueOf(metadata)

	for i := 0; i < t.NumField(); i++ {
		if v.Field(i).Interface().(string) == "" {
			continue
		}
		writeContent := "export " + t.Field(i).Name + "=" + v.Field(i).Interface().(string) + "\n"
		_, err := invokeFile.WriteString(writeContent)
		if err != nil {
			logrus.Errorln(err)
			logrus.Fatalf("[FluentBit Init Process] Cannot write %s in the invoke_fluent_bit.sh\n", writeContent[:len(writeContent)-2])
		}
	}
}

// create Fluent Bit command to use "-c" to specify the new main config file
func createCommand(command *string, filePath string) {
	*command = *command + " -c " + filePath
}

// get our built in config files or files from s3
// process built-in config files directly
// add S3 config files to directory "/init/fluent-bit-init-s3-files/"
func getAllConfigFiles() {
	// get all env vars in the container
	envs := os.Environ()

	// find all env vars match specified prefix
	for _, env := range envs {
		var envKey string
		var envValue string
		env_kv := strings.SplitN(env, "=", 2)
		if len(env_kv) != 2 {
			logrus.Fatalf("[FluentBit Init Process] Unrecognizable environment variables: %s\n", env)
		}

		envKey = string(env_kv[0])
		envValue = string(env_kv[1])

		s3_regex, _ := regexp.Compile("aws_fluent_bit_init_[sS]3")
		file_regex, _ := regexp.Compile("aws_fluent_bit_init_[fF]ile")

		matched_s3 := s3_regex.MatchString(envKey)
		matched_file := file_regex.MatchString(envKey)

		// if this env var's value is an arn, download the config file first, then process it
		if matched_s3 {
			s3FilePath := getS3ConfigFile(envValue)
			s3FileName := strings.SplitN(s3FilePath, "/", -1)
			processConfigFile(s3FileDirectoryPath + s3FileName[len(s3FileName)-1])
		}
		// if this env var's value is a path of our built-in config file, process is derectly
		if matched_file {
			processConfigFile(envValue)
		}
	}
}

func processConfigFile(path string) {
	contentBytes, err := ioutil.ReadFile(path)
	if err != nil {
		logrus.Errorln(err)
		logrus.Fatalf("[FluentBit Init Process] Cannot open file: %s\n", path)
	}

	content := string(contentBytes)

	if strings.Contains(content, "[PARSER]") {
		// this is a parser config file, change command
		updateCommand(path)
	} else {
		// this is not a parser config file. @INCLUDE
		writeInclude(path, mainConfigFile)
	}
}

func getS3ConfigFile(arn string) string {
	// Preparation for downloading S3 config files
	if !s3ClientCreated {
		createS3Client()
	}

	// e.g. "arn:aws:s3:::user-bucket/s3_parser.conf"
	arnBucketFile := arn[13:]
	bucketAndFile := strings.SplitN(arnBucketFile, "/", 2)
	if len(bucketAndFile) != 2 {
		logrus.Fatalf("[FluentBit Init Process] Unrecognizable arn: %s\n", arn)
	}

	bucketName := bucketAndFile[0]
	s3FilePath := bucketAndFile[1]

	// get bucket region
	input := &s3.GetBucketLocationInput{
		Bucket: aws.String(bucketName),
	}

	output, err := s3Client.GetBucketLocation(input)
	if err != nil {
		logrus.Errorln(err)
		logrus.Fatalf("[FluentBit Init Process] Cannot get bucket region of %s + %s, you must be the bucket owner to implement this operation\n", bucketName, s3FilePath)
	}

	bucketRegion := aws.StringValue(output.LocationConstraint)
	// Buckets in Region us-east-1 have a LocationConstraint of null
	// https://docs.aws.amazon.com/sdk-for-go/api/service/s3/#GetBucketLocationOutput
	if bucketRegion == "" {
		bucketRegion = "us-east-1"
	}

	// create a downloader
	s3Downloader := createS3Downloader(bucketRegion)

	// download file from S3 and store in the directory "/init/fluent-bit-init-s3-files/"
	downloadS3ConfigFile(s3Downloader, s3FilePath, bucketName, s3FileDirectoryPath)

	return s3FilePath
}

// create a S3 client as the global S3 client for reuse
func createS3Client() {
	region := "us-east-1"
	if metadataRegion != "" {
		region = metadataRegion
	}

	s3Client = s3.New(session.Must(session.NewSession(&aws.Config{
		// if not specify region here, missingregion error will raise when get bucket location
		Region: aws.String(region),
	})))

	s3ClientCreated = true
}

func createS3Downloader(bucketRegion string) S3Downloader {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(bucketRegion)},
	)
	if err != nil {
		logrus.Errorln(err)
		logrus.Fatalln("[FluentBit Init Process] Cannot creat a new session")
	}

	// need to specify session region!
	s3Downloader := s3manager.NewDownloader(sess)
	return s3Downloader
}

func downloadS3ConfigFile(s3Downloader S3Downloader, s3FilePath, bucketName, s3FileDirectory string) {
	s3FileName := strings.SplitN(s3FilePath, "/", -1)
	fileFromS3 := createFile(s3FileDirectory+s3FileName[len(s3FileName)-1], false)
	defer fileFromS3.Close()

	_, err := s3Downloader.Download(fileFromS3,
		&s3.GetObjectInput{
			Bucket: aws.String(bucketName),
			Key:    aws.String(s3FilePath),
		})
	if err != nil {
		logrus.Warnf("[FluentBit Init Process] Cannot download %s from s3, retrying...\n", s3FileName)

		_, error := s3Downloader.Download(fileFromS3,
			&s3.GetObjectInput{
				Bucket: aws.String(bucketName),
				Key:    aws.String(s3FilePath),
			})
		if error != nil {
			logrus.Errorln(error)
			logrus.Fatalf("[FluentBit Init Process] Cannot download %s from s3\n", s3FileName)
		}
	}
}

// use @INCLUDE to add config files to the main config file
func writeInclude(configFilePath, mainConfigFilePath string) {
	mainConfigFile := openFile(mainConfigFilePath)
	defer mainConfigFile.Close()

	writeContent := "@INCLUDE " + configFilePath + "\n"
	_, err := mainConfigFile.WriteString(writeContent)
	if err != nil {
		logrus.Errorln(err)
		logrus.Fatalf("[FluentBit Init Process] Cannot write %s in main config file: %s\n", writeContent[:len(writeContent)-2], mainConfigFilePath)
	}
}

// change the fluent bit cammand to use "-R" to specift Parser config file
func updateCommand(parserFilePath string) {
	baseCommand = baseCommand + " -R " + parserFilePath
	logrus.Infoln("[FluentBit Init Process] Command is change to -> " + baseCommand)
}

// change the invoke_fluent_bit.sh
// which will declare ECS Task Metadata as environment variables
// and finally invoke Fluent Bit
func modifyInvokeFile(filePath string) {
	invokeFile := openFile(filePath)
	defer invokeFile.Close()

	_, err := invokeFile.WriteString(baseCommand)
	if err != nil {
		logrus.Errorln(err)
		logrus.Fatalf("[FluentBit Init Process] Cannot write %s in invoke_fluent_bit.sh\n", baseCommand)
	}
}

// create a file, when flag is true, the file will be closed automatically after creation
func createFile(filePath string, AutoClose bool) *os.File {
	if err := os.MkdirAll(filepath.Dir(filePath), 0700); err != nil {
		logrus.Errorln(err)
		logrus.Fatalf("[FluentBit Init Process] Cannot create the Directory: %s\n", filepath.Dir(filePath))
	}

	file, err := os.Create(filePath)
	if err != nil {
		logrus.Errorln(err)
		logrus.Fatalf("[FluentBit Init Process] Cannot create the file: %s\n", filePath)
	}

	if AutoClose {
		defer file.Close()
	}

	return file
}

func openFile(filePath string) *os.File {
	file, err := os.OpenFile(filePath, os.O_APPEND|os.O_WRONLY, 0700)
	if err != nil {
		logrus.Errorln(err)
		logrus.Fatalf("[FluentBit Init Process] Unable to read %s\n", filePath)
	}
	return file
}

func main() {
	// create the invoke_fluent_bit.sh
	// which will declare ECS Task Metadata as environment variables
	// and finally invoke Fluent Bit
	createFile(invokeFile, true)

	// get ECS Task Metadata and set the region for S3 client
	httpClient := &http.Client{}
	metadata := getECSTaskMetadata(httpClient)

	// set ECS Task Metada as env vars in the invoke_fluent_bit.sh
	setECSTaskMetadata(metadata, invokeFile)

	// create main config file which will be used invoke Fluent Bit
	createFile(mainConfigFile, true)

	// add @INCLUDE in main config file to include original main config file
	writeInclude(originalMainConfigFile, mainConfigFile)

	// create Fluent Bit command to use "-c" to specify new main config file
	createCommand(&baseCommand, mainConfigFile)

	// get our built in config files or files from s3
	// process built-in config files directly
	// add S3 config files to directory "/init/fluent-bit-init-s3-files/"
	getAllConfigFiles()

	// modify invoke_fluent_bit.sh, invoke fluent bit
	// this function will be called at the end
	// any error appear above will cause exit this process,
	// will not write Fluent Bit command in the finvoke_fluent_bit.sh so Fluent Bit will not be invoked
	modifyInvokeFile(invokeFile)
}
