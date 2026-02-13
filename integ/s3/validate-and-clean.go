package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
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
		exitErrorf("[TEST FAILURE] test verification file name required. Set the value for environment variable- %s", envTestFile)
	}

	expectedEventsLen := os.Getenv(envExpectedLogsLen)
	if expectedEventsLen == "" {
		exitErrorf("[TEST FAILURE] number of expected log events required. Set the value for environment variable- %s", envExpectedLogsLen)
	}
	numEvents, conversionError := strconv.Atoi(expectedEventsLen)
	if conversionError != nil {
		exitErrorf("[TEST FAILURE] String to Int conversion Error for EXPECTED_EVENTS_LEN:", conversionError)
	}

	s3Client, err := getS3Client(region)
	if err != nil {
		exitErrorf("[TEST FAILURE] Unable to create new S3 client: %v", err)
	}

	s3Action := os.Getenv(envS3Action)
	if s3Action == "validate" {
		// Validate the data on the s3 bucket
		for i := 0; i <= retries; i++ {
			success, canRetry := validate(context.TODO(), s3Client, prefix, bucket, testFile, numEvents)
			if success {
				fmt.Println("[VALIDATION SUCCESSFUL]")
				break
			} else if !canRetry {
				break
			}
			time.Sleep(retrySleep * time.Second)
		}
	} else {
		// Clean the s3 bucket-- delete all objects
		for i := 0; i <= retries; i++ {
			success := deleteS3Objects(context.TODO(), s3Client, bucket, prefix)
			if success {
				break
			}
			time.Sleep(retrySleep * time.Second)
		}
	}
}

// Creates a new S3 Client
func getS3Client(region string) (*s3.Client, error) {
	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithRegion(region),
	)
	if err != nil {
		return nil, err
	}

	return s3.NewFromConfig(cfg), nil
}

// Returns all the objects from a S3 bucket with the given prefix
func getS3Objects(ctx context.Context, s3Client *s3.Client, bucket string, prefix string) (*s3.ListObjectsV2Output, error) {
	input := &s3.ListObjectsV2Input{
		Bucket:  aws.String(bucket),
		MaxKeys: aws.Int32(100),
		Prefix:  aws.String(prefix),
	}

	return s3Client.ListObjectsV2(ctx, input)
}

// Validates the log messages. Our log producer is designed to send 1000 integers [0 - 999].
// Both of the Kinesis Streams and Kinesis Firehose try to send each log maintaining the "at least once" policy.
// To validate, we need to make sure all the valid numbers [0 - 999] are stored at least once.
// returns success, can retry
// if the failure was on a network call, then we can retry
func validate(ctx context.Context, s3Client *s3.Client, prefix string, bucket string, testFile string, numEvents int) (bool, bool) {
	response, err := getS3Objects(ctx, s3Client, bucket, prefix)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[TEST FAILURE] Error occurred to get the objects from bucket: %q., %v", bucket, err)
		return false, true
	}

	logCounter := make([]int, numEvents)
	for index := range logCounter {
		logCounter[index] = 1
	}

	for _, object := range response.Contents {
		input := &s3.GetObjectInput{
			Bucket: aws.String(bucket),
			Key:    object.Key,
		}
		obj, err := getS3Object(ctx, s3Client, input)
		if err != nil {
			fmt.Fprintf(os.Stderr, "[TEST FAILURE] Error occurred to get s3 object: %v", err)
			return false, true
		}

		dataByte, err := io.ReadAll(obj.Body)
		if err != nil {
			fmt.Fprintf(os.Stderr, "[TEST FAILURE] Error to parse GetObject response. %v", err)
			return false, true
		}
		defer obj.Body.Close()

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
				fmt.Fprintf(os.Stderr, "[TEST FAILURE] Json Unmarshal Error: %v", decodeError)
				return false, false
			}

			if runtime.GOOS == "windows" {
				// On Windows, we would have additional \r which needs to be stripped.
				message.Log = strings.ReplaceAll(message.Log, "\r", "")
			}

			number, conversionError := strconv.Atoi(message.Log)
			if conversionError != nil {
				fmt.Fprintf(os.Stderr, "[TEST FAILURE] String to Int conversion Error: %v", conversionError)
				return false, false
			}

			if number < 0 || number >= numEvents {
				fmt.Fprintf(os.Stderr, "[TEST FAILURE] Invalid number: %d found. Expected value in range (0 - %d)", number, numEvents)
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
		fmt.Fprintf(os.Stderr, "[TEST FAILURE] Validation Failed. Number of missing log records: %d", sum)
		return false, false
	} else {
		fmt.Println("[TEST SUCCESSFUL] Found all the log records.")
		// The file was created when the integ test started. Removing this file as a flag of test success.
		os.Remove(filepath.Join("/out", testFile))
		return true, false
	}
}

// Retrieves an object from a S3 bucket
func getS3Object(ctx context.Context, s3Client *s3.Client, input *s3.GetObjectInput) (*s3.GetObjectOutput, error) {
	return s3Client.GetObject(ctx, input)
}

// Helper function to batch delete S3 objects
// Handles the common logic of deleting objects in batches of 1000 (S3 API limit)
func batchDeleteS3Objects(ctx context.Context, s3Client *s3.Client, bucket string, objectIds []types.ObjectIdentifier, operationType string) bool {
	if len(objectIds) == 0 {
		return true
	}

	// Delete the objects in batches of 1000 (S3 API limit)
	for i := 0; i < len(objectIds); i += 1000 {
		end := i + 1000
		if end > len(objectIds) {
			end = len(objectIds)
		}

		deleteInput := &s3.DeleteObjectsInput{
			Bucket: aws.String(bucket),
			Delete: &types.Delete{
				Objects: objectIds[i:end],
				Quiet:   aws.Bool(true),
			},
		}

		_, err := s3Client.DeleteObjects(ctx, deleteInput)
		if err != nil {
			fmt.Fprintf(os.Stderr, "[CLEAN FAILURE] Unable to delete %s from bucket %q: %v", operationType, bucket, err)
			return false
		}
	}

	return true
}

// Delete all the objects with the given prefix from the specified S3 bucket
// Also deletes all object versions if the bucket has versioning enabled
func deleteS3Objects(ctx context.Context, s3Client *s3.Client, bucket string, prefix string) bool {
	// First delete all object versions if versioning is enabled
	if !deleteS3ObjectVersions(ctx, s3Client, bucket, prefix) {
		return false
	}

	// Then delete all current objects
	// List objects to delete
	listInput := &s3.ListObjectsV2Input{
		Bucket: aws.String(bucket),
		Prefix: aws.String(prefix),
	}

	paginator := s3.NewListObjectsV2Paginator(s3Client, listInput)

	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			fmt.Fprintf(os.Stderr, "[CLEAN FAILURE] Unable to list objects in bucket %q: %v", bucket, err)
			return false
		}

		if len(page.Contents) == 0 {
			continue
		}

		// Create delete objects input with objects from this page
		var objectIds []types.ObjectIdentifier
		for _, obj := range page.Contents {
			objectIds = append(objectIds, types.ObjectIdentifier{
				Key: obj.Key,
			})
		}

		if !batchDeleteS3Objects(ctx, s3Client, bucket, objectIds, "objects") {
			return false
		}
	}

	fmt.Println("[CLEAN SUCCESSFUL] All the objects are deleted from the bucket:", bucket)
	return true
}

// Delete all object versions with the given prefix from the specified S3 bucket
func deleteS3ObjectVersions(ctx context.Context, s3Client *s3.Client, bucket string, prefix string) bool {
	// List object versions to delete
	listInput := &s3.ListObjectVersionsInput{
		Bucket: aws.String(bucket),
		Prefix: aws.String(prefix),
	}

	paginator := s3.NewListObjectVersionsPaginator(s3Client, listInput)

	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			fmt.Fprintf(os.Stderr, "[CLEAN FAILURE] Unable to list object versions in bucket %q: %v", bucket, err)
			return false
		}

		// Process versions and delete markers
		var objectIds []types.ObjectIdentifier

		// Add versions
		for _, version := range page.Versions {
			objectIds = append(objectIds, types.ObjectIdentifier{
				Key:       version.Key,
				VersionId: version.VersionId,
			})
		}

		// Add delete markers
		for _, marker := range page.DeleteMarkers {
			objectIds = append(objectIds, types.ObjectIdentifier{
				Key:       marker.Key,
				VersionId: marker.VersionId,
			})
		}

		if !batchDeleteS3Objects(ctx, s3Client, bucket, objectIds, "object versions") {
			return false
		}
	}

	fmt.Println("[CLEAN SUCCESSFUL] All object versions are deleted from the bucket:", bucket)
	return true
}

func exitErrorf(msg string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, msg+"\n", args...)
	os.Exit(1)
}
