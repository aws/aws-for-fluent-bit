#!/bin/bash

# Using CloudFormation describe-stacks extracts the output values for kinesis stream and s3 bucket name, and sets them as environment variables
ARCHITECTURE=$(uname -m | tr '_' '-')
# For arm, uname evaluates to 'aarch64' but everywhere else in the pipline
# we use 'arm64'
if [ "$ARCHITECTURE" = "aarch64" ]; then
    ARCHITECTURE="arm64"
fi
stackOutputs=$(aws cloudformation describe-stacks --region "$AWS_REGION" --stack-name integ-test-fluent-bit-${ARCHITECTURE} --output text --query 'Stacks[0].Outputs[*].OutputValue')
read -r -a outputArray <<< "$stackOutputs"
export FIREHOSE_STREAM="${outputArray[0]}"
export KINESIS_STREAM="${outputArray[1]}"
export S3_BUCKET_NAME="${outputArray[2]}"
