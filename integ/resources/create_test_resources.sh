#!/bin/bash

# Deploys the CloudFormation template to create the stack and necessary resources- kinesis data stream, s3 bucket, and kinesis firehose delivery stream
# Resource (stream, s3, delivery stream) names will start with the stack name followed by the corresponding architecture. "integ-test-fluent-bit-architecture"
ARCHITECTURE=$(uname -m | tr '_' '-')
# For arm, uname evaluates to 'aarch64' but everywhere else in the pipline
# we use 'arm64'
if [ "$ARCHITECTURE" = "aarch64" ]; then
    ARCHITECTURE="arm64"
fi
aws cloudformation deploy --template-file ./integ/resources/cfn-kinesis-s3-firehose.yml --stack-name integ-test-fluent-bit-${ARCHITECTURE} --region "$AWS_REGION" --capabilities CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset
