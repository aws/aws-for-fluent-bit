#!/bin/bash
# Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
# 	http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.
set -e

# Validate BUILD_VERSION variable is set
if [ "$BUILD_VERSION" != "2" ] && [ "$BUILD_VERSION" != "3" ]; then
    echo "Unsupported BUILD_VERSION: $BUILD_VERSION"
    echo "Supported versions are: 2, 3"
    exit 1
fi

# Enforce STS regional endpoints
export AWS_STS_REGIONAL_ENDPOINTS=regional
export CW_INTEG_VALIDATOR_IMAGE_BASE=${AWS_ACCOUNT}.dkr.ecr.us-west-2.amazonaws.com/cw-integ-validator
export S3_INTEG_VALIDATOR_IMAGE_BASE=${AWS_ACCOUNT}.dkr.ecr.us-west-2.amazonaws.com/s3-integ-validator
# Get the default credentials and set as environment variables
CREDS=`curl 169.254.170.2$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI`
export AWS_ACCESS_KEY_ID=`echo $CREDS | jq -r .AccessKeyId`
export AWS_SECRET_ACCESS_KEY=`echo $CREDS | jq -r .SecretAccessKey`
export AWS_SESSION_TOKEN=`echo $CREDS | jq -r .Token`

# Pull the image that we built and pushed in the `Build` stage
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com

if [ "$BUILD_VERSION" = "2" ]; then
    IMAGE_TAG="latest"
elif [ "$BUILD_VERSION" = "3" ]; then
    IMAGE_TAG="latest-3"
fi

docker pull ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:${IMAGE_TAG}
docker tag ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:${IMAGE_TAG} amazon/aws-for-fluent-bit:latest

# List the images to do a double check
docker images

# Command to run the integration test
make integ