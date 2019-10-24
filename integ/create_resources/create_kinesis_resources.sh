#!/bin/bash

# Deploys the CloudFormation template to create the stack and necessary resources- kinesis data stream, s3 bucket, and kinesis firehose delivery stream
# The stack name would be- "integ-test-kinesis"
# Resource (stream, s3, delivery stream) names will start with the stack name "integ-test-kinesis"
aws cloudformation deploy --template-file ./integ/create_resources/cf-kinesis-s3-firehose.yml --stack-name integ-test-kinesis --region us-west-2 --capabilities CAPABILITY_NAMED_IAM

# Using CloudFormation describe-stacks extracts the output values for kinesis stream and s3 bucket name, and sets them as environment variables
stackOutputs=$(aws cloudformation describe-stacks --stack-name integ-test-kinesis --output text --query 'Stacks[0].Outputs[*].OutputValue')
read -r -a outputArray <<< "$stackOutputs"
echo "Kinesis Stream: ${outputArray[0]}"
echo "S3 Bucket Name: ${outputArray[1]}"
export KINESIS_STREAM="${outputArray[0]}"
export S3_BUCKET_NAME="${outputArray[1]}"