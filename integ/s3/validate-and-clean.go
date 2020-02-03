package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
)

const (
	envAWSRegion = "AWS_REGION"
	envS3Bucket  = "S3_BUCKET_NAME"
	envS3Action  = "S3_ACTION"
	envS3Prefix  = "S3_PREFIX"
	envTestFile  = "TEST_FILE"
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

	s3Client, err := getS3Client(region)
	if err != nil {
		exitErrorf("[TEST FAILURE] Unable to create new S3 client: %v", err)
	}

	s3Action := os.Getenv(envS3Action)
	if s3Action == "validate" {
		// Validate the data on the s3 bucket
		getS3ObjectsResponse := getS3Objects(s3Client, bucket, prefix)
		validate(s3Client, getS3ObjectsResponse, bucket, testFile)
	} else {
		// Clean the s3 bucket-- delete all objects
		deleteS3Objects(s3Client, bucket, prefix)
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
		exitErrorf("[TEST FAILURE] Error occured to get the objects from bucket: %q., %v", bucket, err)
	}

	return response
}

// Validates the log messages. Our log producer is designed to send 1000 integers [0 - 999].
// Both of the Kinesis Streams and Kinesis Firehose try to send each log maintaining the "at least once" policy.
// To validate, we need to make sure all the valid numbers [0 - 999] are stored at least once.
func validate(s3Client *s3.S3, response *s3.ListObjectsV2Output, bucket string, testFile string) {
	logCounter := make([]int, 1000)
	for index := range logCounter {
		logCounter[index] = 1
	}

	for i := range response.Contents {
		input := &s3.GetObjectInput{
			Bucket: aws.String(bucket),
			Key:    response.Contents[i].Key,
		}
		obj := getS3Object(s3Client, input)

		dataByte, err := ioutil.ReadAll(obj.Body)
		if err != nil {
			exitErrorf("[TEST FAILURE] Error to parse GetObject response. %v", err)
		}

		data := strings.Split(string(dataByte), "\n")

		for _, d := range data {
			if d == "" {
				continue
			}

			var message Message

			decodeError := json.Unmarshal([]byte(d), &message)
			if decodeError != nil {
				exitErrorf("[TEST FAILURE] Json Unmarshal Error:", decodeError)
			}

			number, convertionError := strconv.Atoi(message.Log)
			if convertionError != nil {
				exitErrorf("[TEST FAILURE] String to Int convertion Error:", convertionError)
			}

			if number < 0 || number >= 1000 {
				exitErrorf("[TEST FAILURE] Invalid number: %d found. Expected value in range (0 - 999)", number)
			}

			logCounter[number] = 0
		}

	}
	sum := 0
	for i := range logCounter {
		sum += logCounter[i]
	}

	if sum > 0 {
		exitErrorf("[TEST FAILURE] Validation Failed. Number of missing log records: %d", sum)
	} else {
		fmt.Println("[TEST SUCCESSFULL] Found all the log records.")
		// The file was created when the integ test started. Removing this file as a flag of test success.
		os.Remove(filepath.Join("/out", testFile))
	}
}

// Retrieves an object from a S3 bucket
func getS3Object(s3Client *s3.S3, input *s3.GetObjectInput) *s3.GetObjectOutput {
	obj, err := s3Client.GetObject(input)

	if err != nil {
		exitErrorf("[TEST FAILURE] Error occured to get s3 object: %v", err)
	}

	return obj
}

// Delete all the objects with the given prefix from the specified S3 bucket
func deleteS3Objects(s3Client *s3.S3, bucket string, prefix string) {
	// Setup BatchDeleteIterator to iterate through a list of objects.
	iter := s3manager.NewDeleteListIterator(s3Client, &s3.ListObjectsInput{
		Bucket: aws.String(bucket),
		Prefix: aws.String(prefix),
	})

	// Traverse the iterator deleting each object
	if err := s3manager.NewBatchDeleteWithClient(s3Client).Delete(aws.BackgroundContext(), iter); err != nil {
		exitErrorf("[CLEAN FAILURE] Unable to delete the objects from the bucket %q., %v", bucket, err)
	}

	fmt.Println("[CLEAN SUCCESSFUL] All the objects are deleted from the bucket:", bucket)
}

func exitErrorf(msg string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, msg+"\n", args...)
	os.Exit(1)
}
