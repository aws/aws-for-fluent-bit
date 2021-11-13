#!/bin/bash

# Use CloudFormation describe-stacks extracts the output values for cloudwatch log group name, s3 bucket name and ecs cluster name, and sets them as environment variables
stackOutputs=$(aws cloudformation describe-stacks --stack-name ${TESTING_RESOURCES_STACK_NAME} --output text --query 'Stacks[0].Outputs[*].OutputValue')
read -r -a outputArray <<< "$stackOutputs"
export ECS_CLUSTER_NAME="${outputArray[0]}"
export CW_LOG_GROUP_NAME="${outputArray[1]}"
stackOutputs=$(aws cloudformation describe-stacks --stack-name ${LOG_STORAGE_STACK_NAME} --output text --query 'Stacks[0].Outputs[*].OutputValue')
read -r -a outputArray <<< "$stackOutputs"
export S3_BUCKET_NAME="${outputArray[0]}"
# Set load tests related data streams and delivery streams as environment variables. These resources are predefined and created in stack load-test-fluent-bit-log-storage
ThroughputArray=("1m" "2m" "3m" "20m" "25m" "30m")
for i in "${ThroughputArray[@]}"; do
    export KINESIS_TEST_${i}="${PREFIX}ecs-kinesisStream-${i}"
    export FIREHOSE_TEST_${i}="${PREFIX}ecs-firehoseTest-deliveryStream-${i}"
done
# Set necessary images as env vars
export FLUENT_BIT_IMAGE="${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:latest"
export APP_IMAGE="075490442118.dkr.ecr.us-west-2.amazonaws.com/load-test-fluent-bit-app-image:latest"