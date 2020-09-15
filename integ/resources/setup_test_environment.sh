#!/bin/bash

# Using CloudFormation describe-stacks extracts the output values for kinesis stream and s3 bucket name, and sets them as environment variables
ARCHITECTURE=$(uname -m)
if [ ARCHITECTURE=="x86_64" ] 
then
    ARCHITECTURE="x86-64"
fi
stackOutputs=$(aws cloudformation describe-stacks --stack-name integ-test-fluent-bit-${ARCHITECTURE} --output text --query 'Stacks[0].Outputs[*].OutputValue')
read -r -a outputArray <<< "$stackOutputs"
export FIREHOSE_STREAM="${outputArray[0]}"
export KINESIS_STREAM="${outputArray[1]}"
export S3_BUCKET_NAME="${outputArray[2]}"
