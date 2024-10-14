package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
)

const (
	envAWSRegion       = "AWS_REGION"
	envS3Bucket        = "S3_BUCKET_NAME"
	envS3Action        = "S3_ACTION"
	envS3Prefix        = "S3_PREFIX"
	envTestFile        = "TEST_FILE"
	envExpectedLogsLen = "EXPECTED_EVENTS_LEN"
	retries            = 2
	retrySleep         = 5
)

type Message struct {
	Log string
}

func main() {
	region := os.Getenv(envAWSRegion)
	if region == "" {
		exitErrorf("[TEST FAILURE] AWS Region required. Set the value for environment variable- %s", envAWSRegion)
	}

	bucket := os.Getenv(envS3Bucket)
	if bucket == "" {
		exitErrorf("[TEST FAILURE] Bucket name required. Set the value for environment variable- %s", envS3Bucket)
	}

	prefix := os.Getenv(envS3Prefix)
	if prefix == "" {
		exitErrorf("[TEST FAILURE] S3 object prefix required. Set the value for environment variable- %s", envS3Prefix)
	}

	testFile := os.Getenv(envTestFile)
	if testFile == "" {
		exitErrorf("[TEST FAILURE] test verfication file name required. Set the value for environment variable- %s", envTestFile)
	}

	expectedEventsLen := os.Getenv(envExpectedLogsLen)
	if expectedEventsLen == "" {
		exitErrorf("[TEST FAILURE] number of expected log events required. Set the value for environment variable- %s", envExpectedLogsLen)
	}
	numEvents, convertionError := strconv.Atoi(expectedEventsLen)
	if convertionError != nil {
		exitErrorf("[TEST FAILURE] String to Int convertion Error for EXPECTED_EVENTS_LEN:", convertionError)
	}

	s3Client, err := getS3Client(region)
	if err != nil {
		exitErrorf("[TEST FAILURE] Unable to create new S3 client: %v", err)
	}

	s3Action := os.Getenv(envS3Action)
	if s3Action == "validate" {
		// Validate the data on the s3 bucket
		for i := 0; i <= retries; i++ {
			success, canRetry := validate(s3Client, prefix, bucket, testFile, numEvents)
			if success {
				fmt.Println("[VALIDATION SUCCESSFULL]")
				break
			} else if !canRetry {
				break
			}
			time.Sleep(retrySleep * time.Second)
		}
	} else {
		// Clean the s3 bucket-- delete all objects
		for i := 0; i <= retries; i++ {
			success := deleteS3Objects(s3Client, bucket, prefix)
			if success {
				break
			}
			time.Sleep(retrySleep * time.Second)
		}
		
	}
}

// Creates a new S3 Client
func getS3Client(region string) (*s3.S3, error) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region)},
	)

	if err != nil {
		return nil, err
	}

	return s3.New(sess), nil
}

// Returns all the objects from a S3 bucket with the given prefix
func getS3Objects(s3Client *s3.S3, bucket string, prefix string) *s3.ListObjectsV2Output {
	input := &s3.ListObjectsV2Input{
		Bucket:  aws.String(bucket),
		MaxKeys: aws.Int64(100),
		Prefix:  aws.String(prefix),
	}

	response, err := s3Client.ListObjectsV2(input)

	if err != nil {
		fmt.Fprintf(os.Stderr,"[TEST FAILURE] Error occured to get the objects from bucket: %q., %v", bucket, err)
		return nil
	}

	return response
}

// Validates the log messages. Our log producer is designed to send 1000 integers [0 - 999].
// Both of the Kinesis Streams and Kinesis Firehose try to send each log maintaining the "at least once" policy.
// To validate, we need to make sure all the valid numbers [0 - 999] are stored at least once.
// returns success, can retry
// if the failure was on a network call, then we can retry
func validate(s3Client *s3.S3, prefix string, bucket string, testFile string, numEvents int) (bool, bool) {
	response := getS3Objects(s3Client, bucket, prefix)
	if response == nil {
		return false, true
	}

	
	logCounter := make([]int, numEvents)
	for index := range logCounter {
		logCounter[index] = 1
	}

	for i := range response.Contents {
		input := &s3.GetObjectInput{
			Bucket: aws.String(bucket),
			Key:    response.Contents[i].Key,
		}
		obj := getS3Object(s3Client, input)
		if obj == nil {
			return false, true
		}

		dataByte, err := io.ReadAll(obj.Body)
		if err != nil {
			fmt.Fprintf(os.Stderr,"[TEST FAILURE] Error to parse GetObject response. %v", err)
			return false, true
		}

		data := strings.Split(string(dataByte), "\n")

		for _, d := range data {
			if d == "" {
				continue
			}
			if len(d) > 500 {
				continue
			}

			var message Message

			decodeError := json.Unmarshal([]byte(d), &message)
			if decodeError != nil {
				fmt.Fprintf(os.Stderr,"[TEST FAILURE] Json Unmarshal Error:", decodeError)
				return false, false
			}

			if runtime.GOOS == "windows" {
				// On Windows, we would have additional \r which needs to be stripped.
				message.Log = strings.ReplaceAll(message.Log, "\r", "")
			}

			number, convertionError := strconv.Atoi(message.Log)
			if convertionError != nil {
				fmt.Fprintf(os.Stderr,"[TEST FAILURE] String to Int convertion Error:", convertionError)
				return false, false
			}

			if number < 0 || number >= numEvents {
				fmt.Fprintf(os.Stderr,"[TEST FAILURE] Invalid number: %d found. Expected value in range (0 - %d)", number, numEvents)
				return false, false
			}

			logCounter[number] = 0
		}

	}
	sum := 0
	for i := range logCounter {
		sum += logCounter[i]
	}

	if sum > 0 {
		fmt.Fprintf(os.Stderr,"[TEST FAILURE] Validation Failed. Number of missing log records: %d", sum)
		return false, false
	} else {
		fmt.Println("[TEST SUCCESSFULL] Found all the log records.")
		// The file was created when the integ test started. Removing this file as a flag of test success.
		os.Remove(filepath.Join("/out", testFile))
		return true, false
	}
}

// Retrieves an object from a S3 bucket
func getS3Object(s3Client *s3.S3, input *s3.GetObjectInput) *s3.GetObjectOutput {
	obj, err := s3Client.GetObject(input)

	if err != nil {
		fmt.Fprintf(os.Stderr,"[TEST FAILURE] Error occured to get s3 object: %v", err)
		return nil
	}

	return obj
}

// Delete all the objects with the given prefix from the specified S3 bucket
func deleteS3Objects(s3Client *s3.S3, bucket string, prefix string) bool {
	// Setup BatchDeleteIterator to iterate through a list of objects.
	iter := s3manager.NewDeleteListIterator(s3Client, &s3.ListObjectsInput{
		Bucket: aws.String(bucket),
		Prefix: aws.String(prefix),
	})

	// Traverse the iterator deleting each object
	if err := s3manager.NewBatchDeleteWithClient(s3Client).Delete(aws.BackgroundContext(), iter); err != nil {
		fmt.Fprintf(os.Stderr,"[CLEAN FAILURE] Unable to delete the objects from the bucket %q., %v", bucket, err)
		return false
	}

	fmt.Println("[CLEAN SUCCESSFUL] All the objects are deleted from the bucket:", bucket)
	return true
}

func exitErrorf(msg string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, msg+"\n", args...)
	os.Exit(1)
}
