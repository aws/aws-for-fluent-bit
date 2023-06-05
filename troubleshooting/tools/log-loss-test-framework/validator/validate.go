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
	// if not running in ECS, can be provided optionally by env vars, for example for test re-runs
	envTaskDefinition    = "ECS_TASK_DEFINITION"
	envCluster           = "ECS_CLUSTER"
	envTaskID            = "ECS_TASK_ID"
	envLaunchType        = "ECS_LAUNCH_TYPE"
	envHistogram         = "HISTOGRAM"
	idCounterBase        = 10000000
	retries              = 3
	histogramBuckets     = 20
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
		// sleep on startup may be needed to give
		// CW time for eventual consistency
		time.Sleep(600 * time.Second)
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
		taskMetadata.AWS_REGION = region
		logStreamName = os.Getenv(envCWLogStream)
		if region == "" {
			exitErrorf("[TEST FAILURE] log stream name required. Set the value for environment variable- %s", envCWLogStream)
		}
		// optionally, add ECS metadata info via env vars
		// used in the test double checker/re-validator
		taskMetadata.ECS_CLUSTER = os.Getenv(envCluster)
		taskMetadata.ECS_LAUNCH_TYPE = os.Getenv(envLaunchType)
		taskMetadata.ECS_TASK_DEFINITION = os.Getenv(envTaskDefinition)
		taskMetadata.ECS_TASK_ID = os.Getenv(envTaskID)
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

	// for cross-region test, support overriding region from ECS with env var
	region = os.Getenv(envAWSRegion)
	if region != "" {
		taskMetadata.AWS_REGION = region
	}

	totalInputRecord := (1000 * totalSizeInMB) / logSizeInKB

	for i := 0; i <= retries; i++ {
		if i != 0 {
			time.Sleep(5 * time.Second)
		}
		// Map for counting unique records in corresponding destination
		inputMap := make(map[string]bool)
		for i := 0; i < totalInputRecord; i++ {
			recordId := strconv.Itoa(idCounterBase + i)
			inputMap[recordId] = false
		}

		totalRecordFound := 0
		cwClient, err := getCWClient(region)
		if err != nil {
			fmt.Println(err)
			continue
		}

		err, totalRecordFound, inputMap = validateCloudwatch(cwClient, logGroup, logStreamName, inputMap)
		if err != nil {
			fmt.Println(err)
			continue
		}

		// Get benchmark results based on log loss, log delay and log duplication
		printResults(totalInputRecord, totalRecordFound, inputMap, logGroup, logStreamName, taskMetadata)
		break
	}
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
func validateCloudwatch(cwClient *cloudwatchlogs.CloudWatchLogs, logGroup string, logStream string, inputMap map[string]bool) (error, int, map[string]bool) {
	var forwardToken *string
	var input *cloudwatchlogs.GetLogEventsInput
	cwRecoredCounter := 0

	makeHistogram := os.Getenv(envHistogram)
	testName := os.Getenv(envTestName)
	if makeHistogram != "" {
		fmt.Printf("\n%s: Querying CW", testName)
	}

	time.Sleep(500 * time.Millisecond)
	
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
				return fmt.Errorf("[TEST FAILURE] Error occured to get the log events from log group: %q., %v", logGroup, err), 0, nil
			}
		}
		if makeHistogram != "" {
			fmt.Printf(".")
		}

		/* sleep between GetLogEvents calls to proactively reduce TPS against CW frontend */
		time.Sleep(500 * time.Millisecond)

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

	
	if makeHistogram != "" {
		fmt.Println(" ")
	}

	return nil, cwRecoredCounter, inputMap
}

func printResults(totalInputRecord int, totalRecordFound int, recordMap map[string]bool, logGroupName string, logStreamName string, metadata ECSTaskMetadata) {
	uniqueRecordFound := 0
	missingRecordCount := 0
	totalSizeInMB := os.Getenv(envTotalSizeInMB)

	logSizeInKB:= os.Getenv(envLogSizeInKB)

	throughputInKB := os.Getenv(envThroughputInKB)

	testName := os.Getenv(envTestName)

	firstLost := 1000000000
	lastLost := 0

	bucketSize := totalInputRecord / histogramBuckets

	hist := os.Getenv(envHistogram)
	var makeHistogram bool = false
	var missingRecords map[int][]int
	if hist != "" {
		makeHistogram = true
		missingRecords = make(map[int][]int)
		for i := 0; i < histogramBuckets; i++ {
			missingRecords[i] = make([]int, 10)
		}
	}

	// fmt.Printf("%s: MISSING RECORDS:", testName)
	// Count how many unique records were found in the destination
	for msg, found := range recordMap {
		if found {
			uniqueRecordFound++
		} else {
			missingRecordCount += 1
			// fmt.Printf("%s, ", msg);
			lostID, err := strconv.Atoi(msg)
			if err == nil {
				if lostID < firstLost {
					firstLost = lostID
				}
				if lostID > lastLost {
					lastLost = lostID
				}
				if makeHistogram {
					bucket := (lostID - idCounterBase) / bucketSize
					missingList := missingRecords[bucket]
					missingList = append(missingList, lostID)
					missingRecords[bucket] = missingList
				}
			}
		}
	}
	// fmt.Printf("\n")

	var hasLogLoss string
	if totalInputRecord != uniqueRecordFound {
		hasLogLoss = "🚨"
	} else {
		hasLogLoss = "✅"
	}

	if (totalInputRecord - uniqueRecordFound) != missingRecordCount {
		fmt.Printf("%s: VALIDATION ERROR: (totalInputRecord - uniqueRecordFound) = %d, missingRecordCount = %d\n", 
					testName, totalInputRecord - uniqueRecordFound, missingRecordCount)
	}

	// if there are many test cases to run
	// perform CW insights query for test name
	// output is comma delimited, output insights query result as CSV
	// simple python code can parse the CSV
	fmt.Printf("%s %s - %s, percent lost, %d, number_lost, %d, total_input_record, %d, duplicates, %d, group=%s stream=%s TOTAL_SIZE_IN_MB=%s, SIZE_IN_KB=%s, THROUGHPUT_IN_KB=%s, %s, %s, %s, %s, %s, first_lost=%d, last_lost=%d",
			   testName, hasLogLoss, throughputInKB, (totalInputRecord-uniqueRecordFound)*100/totalInputRecord, totalInputRecord-uniqueRecordFound, totalInputRecord, totalRecordFound - uniqueRecordFound,
			   logGroupName, logStreamName, totalSizeInMB, logSizeInKB, throughputInKB, metadata.ECS_TASK_ID, metadata.ECS_CLUSTER, metadata.ECS_TASK_DEFINITION, metadata.ECS_LAUNCH_TYPE, metadata.AWS_REGION, firstLost, lastLost)
	fmt.Println()
	fmt.Println()
	if makeHistogram {
		for i := 0; i < histogramBuckets; i++ {
			fmt.Printf("%d: ", i)
			bucket := missingRecords[i]
			for _, lostID := range bucket {
				if lostID != 0 {
					fmt.Printf("%d, ", lostID)
				}
			}
			fmt.Println(" ")
		}
	}
}

func exitErrorf(msg string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, msg+"\n", args...)
	os.Exit(1)
}
