#!/bin/bash

# Using CloudFormation describe-stacks extracts the output values for kinesis stream and s3 bucket name, and sets them as environment variables
stackOutputs=$(aws cloudformation describe-stacks --stack-name integ-test-fluent-bit --output text --query 'Stacks[0].Outputs[*].OutputValue')
read -r -a outputArray <<< "$stackOutputs"
echo "Kinesis Stream: ${outputArray[0]}"
echo "S3 Bucket Name: ${outputArray[1]}"
echo "Firehose Stream: ${outputArray[2]}"
export FIREHOSE_STREAM="${outputArray[0]}"
export KINESIS_STREAM="${outputArray[1]}"
export S3_BUCKET_NAME="${outputArray[2]}"
