package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"strconv"
	"strings"
	"time"
	"net/http"

	"github.com/aws/aws-sdk-go/aws/arn"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/cloudwatchlogs"
)

const (
	envAWSRegion         = "AWS_REGION"
	envCWLogGroup        = "CW_LOG_GROUP_NAME"
	envCWLogStream       = "CW_LOG_STREAM_NAME"
	envCWLogStreamPrefix = "CW_LOG_STREAM_PREFIX"
	envTotalSizeInMB     = "TOTAL_SIZE_IN_MB"
	envLogSizeInKB       = "SIZE_IN_KB"
	envThroughputInKB    = "THROUGHPUT_IN_KB"
	envTestName          = "TEST_NAME"
	idCounterBase        = 10000000
)

type Message struct {
	Log string
}

type ECSTaskMetadata struct {
	AWS_REGION            string `json:"AWSRegion"`
	ECS_CLUSTER           string `json:"Cluster"` // Cluster name
	ECS_TASK_ARN          string `json:"TaskARN"`
	ECS_TASK_ID           string `json:"TaskID"`
	ECS_FAMILY            string `json:"Family"`
	ECS_LAUNCH_TYPE       string `json:"LaunchType"`     // Task launch type will be an empty string if container agent is under version 1.45.0
	ECS_REVISION          string `json:"Revision"`       // Revision number
	ECS_TASK_DEFINITION   string `json:"TaskDefinition"` // TaskDefinition = "family:revision"
}


func main() {
	runningInECS := false
	if (os.Getenv("ECS_CONTAINER_METADATA_URI_V4") != "") {
		runningInECS = true
	}

	var region string
	var logStreamName string
	var taskMetadata ECSTaskMetadata

	if (runningInECS) {
		taskMetadata = getECSTaskMetadata()
		region = taskMetadata.AWS_REGION
		logStreamPrefix := os.Getenv(envCWLogStreamPrefix)
		if logStreamPrefix == "" {
			exitErrorf("[TEST FAILURE] log stream prefix required if running in ECS. Must be full prefix before task ID. Set the value for environment variable- %s", envCWLogStreamPrefix)
		}
		logStreamName = logStreamPrefix + taskMetadata.ECS_TASK_ID
	} else {
		region = os.Getenv(envAWSRegion)
		if region == "" {
			exitErrorf("[TEST FAILURE] AWS Region required. Set the value for environment variable- %s", envAWSRegion)
		}
		logStreamName = os.Getenv(envCWLogStream)
		if region == "" {
			exitErrorf("[TEST FAILURE] log stream name required. Set the value for environment variable- %s", envCWLogStream)
		}
	}

	logGroup := os.Getenv(envCWLogGroup)
	if logGroup == "" {
		exitErrorf("[TEST FAILURE] Log group name required. Set the value for environment variable- %s", envCWLogGroup)
	}

	testName := os.Getenv(envTestName)
	if testName == "" {
		exitErrorf("[TEST FAILURE] Test name required. Set the value for environment variable- %s", envTestName)
	}

	totalSizeInMB, err := strconv.Atoi(os.Getenv(envTotalSizeInMB))
	if err != nil {
		exitErrorf("[TEST FAILURE] total log MB required. Set the value for environment variable- %s", envTotalSizeInMB)
	}

	logSizeInKB, err := strconv.Atoi(os.Getenv(envLogSizeInKB))
	if err != nil {
		exitErrorf("[TEST FAILURE] log msg size required. Set the value for environment variable- %s", envLogSizeInKB)
	}

	totalInputRecord := (1000 * totalSizeInMB) / logSizeInKB
	// Map for counting unique records in corresponding destination
	inputMap := make(map[string]bool)
	for i := 0; i < totalInputRecord; i++ {
		recordId := strconv.Itoa(idCounterBase + i)
		inputMap[recordId] = false
	}

	totalRecordFound := 0
	cwClient, err := getCWClient(region)
	if err != nil {
		exitErrorf("[TEST FAILURE] Unable to create new CloudWatch client: %v", err)
	}

	totalRecordFound, inputMap = validateCloudwatch(cwClient, logGroup, logStreamName, inputMap)

	// Get benchmark results based on log loss, log delay and log duplication
	printResults(totalInputRecord, totalRecordFound, inputMap, logGroup, logGroup, taskMetadata)
}

// get ECS Task Metadata via endpoint V4
// needed so that we can figure out the log stream name from prefix
func getECSTaskMetadata() ECSTaskMetadata {
	httpClient := &http.Client{}
	var metadata ECSTaskMetadata

	ecsTaskMetadataEndpointV4 := os.Getenv("ECS_CONTAINER_METADATA_URI_V4")
	if ecsTaskMetadataEndpointV4 == "" {
		fmt.Println("[CW Log Loss Validator] Unable to get ECS Metadata, ignore this warning if not running on ECS")
		return metadata
	}

	res, err := httpClient.Get(ecsTaskMetadataEndpointV4 + "/task")
	if err != nil {
		fmt.Printf("[CW Log Loss Validator] Failed to get ECS Metadata via HTTP Get: %s\n", err)
		os.Exit(1)
	}

	response, err := ioutil.ReadAll(res.Body)
	if err != nil {
		fmt.Printf("[CW Log Loss Validator] Failed to read ECS Metadata from HTTP response: %s\n", err)
		os.Exit(1)
	}
	res.Body.Close()

	err = json.Unmarshal(response, &metadata)
	if err != nil {
		fmt.Printf("[CW Log Loss Validator] Failed to unmarshal ECS metadata: %s\n", err)
		os.Exit(1)
	}

	arn, err := arn.Parse(metadata.ECS_TASK_ARN)
	if err != nil {
		fmt.Printf("[CW Log Loss Validator] Failed to parse ECS TaskARN: %s\n", err)
		os.Exit(1)
	}

	resourceID := strings.Split(arn.Resource, "/")
	taskID := resourceID[len(resourceID)-1]
	metadata.ECS_TASK_ID = taskID
	metadata.AWS_REGION = arn.Region
	metadata.ECS_TASK_DEFINITION = metadata.ECS_FAMILY + ":" + metadata.ECS_REVISION

	return metadata
}


// Creates a new CloudWatch Client
func getCWClient(region string) (*cloudwatchlogs.CloudWatchLogs, error) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region)},
	)

	if err != nil {
		return nil, err
	}

	return cloudwatchlogs.New(sess), nil
}

// Validate logs in CloudWatch.
// Similar logic as S3 validation.
func validateCloudwatch(cwClient *cloudwatchlogs.CloudWatchLogs, logGroup string, logStream string, inputMap map[string]bool) (int, map[string]bool) {
	var forwardToken *string
	var input *cloudwatchlogs.GetLogEventsInput
	cwRecoredCounter := 0

	// Returns all log events from a CloudWatch log group with the given log stream.
	// This approach utilizes NextForwardToken to pull all log events from the CloudWatch log group.
	for {
		if forwardToken == nil {
			input = &cloudwatchlogs.GetLogEventsInput{
				LogGroupName:  aws.String(logGroup),
				LogStreamName: aws.String(logStream),
				StartFromHead: aws.Bool(true),
			}
		} else {
			input = &cloudwatchlogs.GetLogEventsInput{
				LogGroupName:  aws.String(logGroup),
				LogStreamName: aws.String(logStream),
				NextToken:     forwardToken,
				StartFromHead: aws.Bool(true),
			}
		}

		response, err := cwClient.GetLogEvents(input)
		for err != nil {
			// retry for throttling exception
			if strings.Contains(err.Error(), "ThrottlingException: Rate exceeded") {
				time.Sleep(1 * time.Second)
				response, err = cwClient.GetLogEvents(input)
			} else {
				exitErrorf("[TEST FAILURE] Error occured to get the log events from log group: %q., %v", logGroup, err)
			}
		}

		for _, event := range response.Events {
			log := aws.StringValue(event.Message)

			// First 8 char is the unique record ID
			recordId := log[:8]
			cwRecoredCounter += 1
			if _, ok := inputMap[recordId]; ok {
				// Setting true to indicate that this record was found in the destination
				inputMap[recordId] = true
			}
		}

		// Same NextForwardToken will be returned if we reach the end of the log stream
		if aws.StringValue(response.NextForwardToken) == aws.StringValue(forwardToken) {
			break
		}

		forwardToken = response.NextForwardToken
	}

	return cwRecoredCounter, inputMap
}

func printResults(totalInputRecord int, totalRecordFound int, recordMap map[string]bool, logGroupName string, logStreamName string, metadata ECSTaskMetadata) {
	uniqueRecordFound := 0
	// Count how many unique records were found in the destination
	for _, v := range recordMap {
		if v {
			uniqueRecordFound++
		}
	}

	totalSizeInMB := os.Getenv(envTotalSizeInMB)

	logSizeInKB:= os.Getenv(envLogSizeInKB)

	throughputInKB := os.Getenv(envThroughputInKB)

	testName := os.Getenv(envTestName)

	var hasLogLoss string

	if totalInputRecord != uniqueRecordFound {
		hasLogLoss = "🚨"
	} else {
		hasLogLoss = "✅"
	}

	// if there are many test cases to run
	// perform CW insights query for test name
	// output is comma delimited, output insights query result as CSV
	// simple python code can parse the CSV
	fmt.Printf("%s %s - %s, percent lost, %d, number_lost, %d, total_input_record, %d, duplicates, %d, group=%s stream=%s TOTAL_SIZE_IN_MB=%s, SIZE_IN_MB=%s, THROUGHPUT_IN_KB=%s, %s, %s, %s, %s, %s",
			   testName, hasLogLoss, throughputInKB, (totalInputRecord-uniqueRecordFound)*100/totalInputRecord, totalInputRecord-uniqueRecordFound, totalInputRecord, totalRecordFound - uniqueRecordFound,
			   logGroupName, logStreamName, totalSizeInMB, logSizeInKB, throughputInKB, metadata.ECS_TASK_ID, metadata.ECS_CLUSTER, metadata.ECS_TASK_DEFINITION, metadata.ECS_LAUNCH_TYPE, metadata.AWS_REGION)
}

func exitErrorf(msg string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, msg+"\n", args...)
	os.Exit(1)
}
