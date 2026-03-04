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

echo "Building AWS for Fluent Bit version $BUILD_VERSION"

# Check if publishing is enabled for this BUILD_VERSION
PUBLISH_ENABLED=$(./scripts/get_linux_version.sh "$BUILD_VERSION" "publish")
echo "Publish enabled for BUILD_VERSION=${BUILD_VERSION}? ${PUBLISH_ENABLED}"

if [ "${PUBLISH_ENABLED}" = "false" ]; then
    echo "Publishing is disabled for BUILD_VERSION=${BUILD_VERSION}, skipping build process"
    exit 0
fi

# Get version-specific configuration using linux.version getter script
AL_TAG=$(./scripts/get_linux_version.sh "$BUILD_VERSION" "al-tag")
FLB_VERSION=$(./scripts/get_linux_version.sh "$BUILD_VERSION" "fluent-bit")
FLB_REPOSITORY=$(./scripts/get_linux_version.sh "$BUILD_VERSION" "flb-repository")
AWS_FOR_FLUENT_BIT_VERSION=$(./scripts/get_linux_version.sh "$BUILD_VERSION" "version")
KINESIS_PLUGIN_TAG=$(./scripts/get_linux_version.sh "$BUILD_VERSION" "kinesis-plugin")
FIREHOSE_PLUGIN_TAG=$(./scripts/get_linux_version.sh "$BUILD_VERSION" "firehose-plugin")
CLOUDWATCH_PLUGIN_TAG=$(./scripts/get_linux_version.sh "$BUILD_VERSION" "cloudwatch-plugin")

IMAGE_TAG_SUFFIX=al"$AL_TAG"

echo "Using AL_TAG: $AL_TAG"
echo "Using FLB_VERSION: $FLB_VERSION"
echo "Using FLB_REPOSITORY: $FLB_REPOSITORY"
echo "Using AWS_FOR_FLUENT_BIT_VERSION: $AWS_FOR_FLUENT_BIT_VERSION"
echo "Using KINESIS_PLUGIN_TAG: $KINESIS_PLUGIN_TAG"
echo "Using FIREHOSE_PLUGIN_TAG: $FIREHOSE_PLUGIN_TAG"
echo "Using CLOUDWATCH_PLUGIN_TAG: $CLOUDWATCH_PLUGIN_TAG"

# Check latest image versions from dockerhub and from GitHub source file
./scripts/publish.sh cicd-check-image-version $BUILD_VERSION

# Disable buildkit features
export DOCKER_BUILDKIT=0

# Build aws-for-fluent-bit images
make debug AL_TAG="$AL_TAG" FLB_VERSION="$FLB_VERSION" FLB_REPOSITORY="$FLB_REPOSITORY" AWS_FOR_FLUENT_BIT_VERSION="$AWS_FOR_FLUENT_BIT_VERSION" KINESIS_PLUGIN_TAG="$KINESIS_PLUGIN_TAG" FIREHOSE_PLUGIN_TAG="$FIREHOSE_PLUGIN_TAG" CLOUDWATCH_PLUGIN_TAG="$CLOUDWATCH_PLUGIN_TAG"
make release AL_TAG="$AL_TAG" FLB_VERSION="$FLB_VERSION" FLB_REPOSITORY="$FLB_REPOSITORY" AWS_FOR_FLUENT_BIT_VERSION="$AWS_FOR_FLUENT_BIT_VERSION" KINESIS_PLUGIN_TAG="$KINESIS_PLUGIN_TAG" FIREHOSE_PLUGIN_TAG="$FIREHOSE_PLUGIN_TAG" CLOUDWATCH_PLUGIN_TAG="$CLOUDWATCH_PLUGIN_TAG"

# List the docker images
docker images

# Push the image to ECR with corresponding architecture as the tag.
aws ecr get-login-password --region ${AWS_REGION}| docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
aws ecr create-repository --repository-name amazon/aws-for-fluent-bit-test --image-scanning-configuration scanOnPush=true --region ${AWS_REGION}  || true

architecture=$(docker inspect --format='{{.Architecture}}'  amazon/aws-for-fluent-bit:latest-$IMAGE_TAG_SUFFIX)

# Tag, push and run ECR security scans on image
tag_push_and_scan() {
    local source_image="$1"
    local target_tag="$2"
    
    docker tag $source_image ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$target_tag
    docker push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$target_tag
    ./scripts/publish.sh cicd-verify-ecr-image-scan ${AWS_REGION} amazon/aws-for-fluent-bit-test $target_tag
}

# Create, annotate and push manifest
create_and_push_manifest() {
    local manifest_tag="$1"
    local arm64_tag="$2"
    local amd64_tag="$3"
    
    # Create manifest
    docker manifest create ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$manifest_tag ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$arm64_tag ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$amd64_tag || true
    
    # Annotate with architecture
    docker manifest annotate --arch arm64 ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$manifest_tag ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$arm64_tag || true
    docker manifest annotate --arch amd64 ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$manifest_tag ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$amd64_tag || true
    
    # Inspect for sanity check
    docker manifest inspect ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$manifest_tag || true
    
    # Push manifest
    docker manifest push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$manifest_tag || true
}

# Set image tags based on BUILD_VERSION
if [ "$BUILD_VERSION" = "2" ]; then
    # BUILD_VERSION 2: Use existing tag format
    RELEASE_TAG="$architecture"
    DEBUG_TAG="$architecture-debug"
    INIT_RELEASE_TAG="init-$architecture"
    INIT_DEBUG_TAG="init-$architecture-debug"
else
    # BUILD_VERSION 3: Include BUILD_VERSION in tags
    RELEASE_TAG="$architecture-$BUILD_VERSION"
    DEBUG_TAG="$architecture-debug-$BUILD_VERSION"
    INIT_RELEASE_TAG="init-$architecture-$BUILD_VERSION"
    INIT_DEBUG_TAG="init-$architecture-debug-$BUILD_VERSION"
fi

# Tag, push and run ECR security scan on images
tag_push_and_scan "amazon/aws-for-fluent-bit:latest-$IMAGE_TAG_SUFFIX" "$RELEASE_TAG"
tag_push_and_scan "amazon/aws-for-fluent-bit:debug-$IMAGE_TAG_SUFFIX" "$DEBUG_TAG"

# Images with Init Process
tag_push_and_scan "amazon/aws-for-fluent-bit:init-latest-$IMAGE_TAG_SUFFIX" "$INIT_RELEASE_TAG"
tag_push_and_scan "amazon/aws-for-fluent-bit:init-debug-$IMAGE_TAG_SUFFIX" "$INIT_DEBUG_TAG"

# Create manifest list
export DOCKER_CLI_EXPERIMENTAL=enabled

# Set manifest tags based on BUILD_VERSION
if [ "$BUILD_VERSION" = "2" ]; then
    # BUILD_VERSION 2: Use existing manifest format
    MANIFEST_LATEST_TAG="latest"
    MANIFEST_INIT_TAG="init-latest"
    MANIFEST_DEBUG_TAG="debug-latest"
    MANIFEST_INIT_DEBUG_TAG="init-debug-latest"
    ARM64_TAG="arm64"
    AMD64_TAG="amd64"
    INIT_ARM64_TAG="init-arm64"
    INIT_AMD64_TAG="init-amd64"
    DEBUG_ARM64_TAG="arm64-debug"
    DEBUG_AMD64_TAG="amd64-debug"
    INIT_DEBUG_ARM64_TAG="init-arm64-debug"
    INIT_DEBUG_AMD64_TAG="init-amd64-debug"
else
    # BUILD_VERSION 3: Include BUILD_VERSION in manifest tags
    MANIFEST_LATEST_TAG="latest-$BUILD_VERSION"
    MANIFEST_INIT_TAG="init-latest-$BUILD_VERSION"
    MANIFEST_DEBUG_TAG="debug-$BUILD_VERSION"
    MANIFEST_INIT_DEBUG_TAG="init-debug-$BUILD_VERSION"
    ARM64_TAG="arm64-$BUILD_VERSION"
    AMD64_TAG="amd64-$BUILD_VERSION"
    INIT_ARM64_TAG="init-arm64-$BUILD_VERSION"
    INIT_AMD64_TAG="init-amd64-$BUILD_VERSION"
    DEBUG_ARM64_TAG="arm64-debug-$BUILD_VERSION"
    DEBUG_AMD64_TAG="amd64-debug-$BUILD_VERSION"
    INIT_DEBUG_ARM64_TAG="init-arm64-debug-$BUILD_VERSION"
    INIT_DEBUG_AMD64_TAG="init-amd64-debug-$BUILD_VERSION"
fi

# Create and push manifests
create_and_push_manifest "$MANIFEST_LATEST_TAG" "$ARM64_TAG" "$AMD64_TAG"
create_and_push_manifest "$MANIFEST_INIT_TAG" "$INIT_ARM64_TAG" "$INIT_AMD64_TAG"
create_and_push_manifest "$MANIFEST_DEBUG_TAG" "$DEBUG_ARM64_TAG" "$DEBUG_AMD64_TAG"
create_and_push_manifest "$MANIFEST_INIT_DEBUG_TAG" "$INIT_DEBUG_ARM64_TAG" "$INIT_DEBUG_AMD64_TAG"
