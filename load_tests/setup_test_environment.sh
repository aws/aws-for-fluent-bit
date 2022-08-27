#!/bin/bash

# Use CloudFormation describe-stacks extracts the output values for cloudwatch log group name, s3 bucket name and ecs cluster name, and sets them as environment variables
stackOutputs=$(aws cloudformation describe-stacks --stack-name ${TESTING_RESOURCES_STACK_NAME} --output text --query 'Stacks[0].Outputs[*].OutputValue')
read -r -a outputArray <<< "$stackOutputs"
if [ $PLATFORM == "ECS" ]
then
    export ECS_CLUSTER_NAME="${outputArray[0]}"
    export CW_LOG_GROUP_NAME="${outputArray[1]}"
else
    export CW_LOG_GROUP_NAME="${outputArray[0]}"
fi
stackOutputs=$(aws cloudformation describe-stacks --stack-name ${LOG_STORAGE_STACK_NAME} --output text --query 'Stacks[0].Outputs[*].OutputValue')
read -r -a outputArray <<< "$stackOutputs"
export S3_BUCKET_NAME="${outputArray[0]}"

# Set necessary images as env vars
export FLUENT_BIT_IMAGE="${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:latest"
export ECS_APP_IMAGE="906394416424.dkr.ecr.us-west-2.amazonaws.com/load-test-fluent-bit-ecs-app-image:latest"
export EKS_APP_IMAGE="906394416424.dkr.ecr.us-west-2.amazonaws.com/load-test-fluent-bit-eks-app-image:latest"
export ECS_APP_IMAGE_TCP="906394416424.dkr.ecr.us-west-2.amazonaws.com/load-test-fluent-bit-ecs-app-image-tcp:latest"
# Label EKS nodes
if [ $PLATFORM == "EKS" ]
then
    DestinationArray=("cloudwatch" "s3" "kinesis" "firehose")
    for i in "${!DestinationArray[@]}"; do 
        export NODE_NAME=$(kubectl get nodes -o json | jq -r ".items[$i].metadata.name")
        kubectl label --overwrite nodes ${NODE_NAME} destination=${DestinationArray[$i]}
    done
fi
