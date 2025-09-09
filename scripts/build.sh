#!/bin/bash
set -e

# Check BUILD_VERSION environment variable and set default if not provided
if [ -z "$BUILD_VERSION" ]; then
    echo "BUILD_VERSION environment variable not provided, defaulting to BUILD_VERSION=2"
    export BUILD_VERSION=2
else
    echo "BUILD_VERSION is set to: $BUILD_VERSION"
fi

# Validate BUILD_VERSION
if [ "$BUILD_VERSION" != "2" ] && [ "$BUILD_VERSION" != "3" ]; then
    echo "Unsupported BUILD_VERSION: $BUILD_VERSION"
    echo "Supported versions are: 2, 3"
    exit 1
fi

echo "Building AWS for Fluent Bit version $BUILD_VERSION"

# Get version-specific configuration using centralized script
AL_TAG=$(./scripts/get_linux_version.sh "$BUILD_VERSION" "al-tag")
FLB_VERSION=$(./scripts/get_linux_version.sh "$BUILD_VERSION" "fluent-bit")
FLB_REPOSITORY=$(./scripts/get_linux_version.sh "$BUILD_VERSION" "flb-repository")

# Get plugin versions for BUILD_VERSION 3
if [ "$BUILD_VERSION" = "3" ]; then
    KINESIS_PLUGIN_TAG=$(./scripts/get_linux_version.sh "$BUILD_VERSION" "kinesis-plugin")
    FIREHOSE_PLUGIN_TAG=$(./scripts/get_linux_version.sh "$BUILD_VERSION" "firehose-plugin")
    CLOUDWATCH_PLUGIN_TAG=$(./scripts/get_linux_version.sh "$BUILD_VERSION" "cloudwatch-plugin")
    
    echo "Using KINESIS_PLUGIN_TAG: $KINESIS_PLUGIN_TAG"
    echo "Using FIREHOSE_PLUGIN_TAG: $FIREHOSE_PLUGIN_TAG"
    echo "Using CLOUDWATCH_PLUGIN_TAG: $CLOUDWATCH_PLUGIN_TAG"
    
    # Export all plugin variables as environment variables for make
    export KINESIS_PLUGIN_TAG FIREHOSE_PLUGIN_TAG CLOUDWATCH_PLUGIN_TAG
fi

echo "Using AL_TAG: $AL_TAG"
echo "Using FLB_VERSION: $FLB_VERSION"
echo "Using FLB_REPOSITORY: $FLB_REPOSITORY"

# Check latest image versions from dockerhub and from GitHub source file
./scripts/publish.sh cicd-check-image-version $BUILD_VERSION

# Disable buildkit features
export DOCKER_BUILDKIT=0

# Command to build debug image with version-specific parameters
if [ "$BUILD_VERSION" = "2" ]; then
    make debug AL_TAG=$AL_TAG FLB_REPOSITORY="$FLB_REPOSITORY"
    make release AL_TAG=$AL_TAG FLB_REPOSITORY="$FLB_REPOSITORY"
else
    # BUILD_VERSION = 3
    make debug AL_TAG=$AL_TAG FLB_VERSION=$FLB_VERSION FLB_REPOSITORY="$FLB_REPOSITORY" KINESIS_PLUGIN_TAG=$KINESIS_PLUGIN_TAG FIREHOSE_PLUGIN_TAG=$FIREHOSE_PLUGIN_TAG CLOUDWATCH_PLUGIN_TAG=$CLOUDWATCH_PLUGIN_TAG
    make release AL_TAG=$AL_TAG FLB_VERSION=$FLB_VERSION FLB_REPOSITORY="$FLB_REPOSITORY" KINESIS_PLUGIN_TAG=$KINESIS_PLUGIN_TAG FIREHOSE_PLUGIN_TAG=$FIREHOSE_PLUGIN_TAG CLOUDWATCH_PLUGIN_TAG=$CLOUDWATCH_PLUGIN_TAG
fi

# List the docker images
docker images

# Push the image to ECR with corresponding architecture as the tag.
aws ecr get-login-password --region ${AWS_REGION}| docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
aws ecr create-repository --repository-name amazon/aws-for-fluent-bit-test --image-scanning-configuration scanOnPush=true --region ${AWS_REGION}  || true

# Get architecture and set image tag suffix based on BUILD_VERSION
# TODO: Simplify logic, just use AL_TAG
if [ "$BUILD_VERSION" = "2" ]; then
    IMAGE_TAG_SUFFIX="al2"
else
    IMAGE_TAG_SUFFIX=al"$AL_TAG"
fi

architecture=$(docker inspect --format='{{.Architecture}}'  amazon/aws-for-fluent-bit:latest-$IMAGE_TAG_SUFFIX)

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
    DEBUG_TAG="$architecture-$BUILD_VERSION-debug"
    INIT_RELEASE_TAG="init-$architecture-$BUILD_VERSION"
    INIT_DEBUG_TAG="init-$architecture-$BUILD_VERSION-debug"
fi

docker tag amazon/aws-for-fluent-bit:latest-$IMAGE_TAG_SUFFIX ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$RELEASE_TAG
docker tag amazon/aws-for-fluent-bit:debug-$IMAGE_TAG_SUFFIX ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$DEBUG_TAG
docker push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$RELEASE_TAG
docker push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$DEBUG_TAG
./scripts/publish.sh cicd-verify-ecr-image-scan ${AWS_REGION} amazon/aws-for-fluent-bit-test $RELEASE_TAG
./scripts/publish.sh cicd-verify-ecr-image-scan ${AWS_REGION} amazon/aws-for-fluent-bit-test $DEBUG_TAG

# Image with Init Process
docker tag amazon/aws-for-fluent-bit:init-latest-$IMAGE_TAG_SUFFIX ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$INIT_RELEASE_TAG
docker tag amazon/aws-for-fluent-bit:init-debug-$IMAGE_TAG_SUFFIX ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$INIT_DEBUG_TAG
docker push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$INIT_RELEASE_TAG
docker push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$INIT_DEBUG_TAG
./scripts/publish.sh cicd-verify-ecr-image-scan ${AWS_REGION} amazon/aws-for-fluent-bit-test $INIT_RELEASE_TAG
./scripts/publish.sh cicd-verify-ecr-image-scan ${AWS_REGION} amazon/aws-for-fluent-bit-test $INIT_DEBUG_TAG

# Create manifest list
export DOCKER_CLI_EXPERIMENTAL=enabled

# Set manifest tags based on BUILD_VERSION
if [ "$BUILD_VERSION" = "2" ]; then
    # BUILD_VERSION 2: Use existing manifest format
    MANIFEST_LATEST_TAG="latest"
    MANIFEST_INIT_TAG="init-latest"
    ARM64_TAG="arm64"
    AMD64_TAG="amd64"
    INIT_ARM64_TAG="init-arm64"
    INIT_AMD64_TAG="init-amd64"
else
    # BUILD_VERSION 3: Include BUILD_VERSION in manifest tags
    MANIFEST_LATEST_TAG="latest-$BUILD_VERSION"
    MANIFEST_INIT_TAG="init-latest-$BUILD_VERSION"
    ARM64_TAG="arm64-$BUILD_VERSION"
    AMD64_TAG="amd64-$BUILD_VERSION"
    INIT_ARM64_TAG="init-arm64-$BUILD_VERSION"
    INIT_AMD64_TAG="init-amd64-$BUILD_VERSION"
fi

docker manifest create ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$MANIFEST_LATEST_TAG ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$ARM64_TAG ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$AMD64_TAG || true
docker manifest annotate --arch arm64 ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$MANIFEST_LATEST_TAG ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$ARM64_TAG || true
docker manifest annotate --arch amd64 ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$MANIFEST_LATEST_TAG ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$AMD64_TAG || true

# Image with Init Process
docker manifest create ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$MANIFEST_INIT_TAG ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$INIT_ARM64_TAG ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$INIT_AMD64_TAG || true
docker manifest annotate --arch arm64 ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$MANIFEST_INIT_TAG ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$INIT_ARM64_TAG || true
docker manifest annotate --arch amd64 ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$MANIFEST_INIT_TAG ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$INIT_AMD64_TAG || true

# Sanity check for the debug log
docker manifest inspect ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$MANIFEST_LATEST_TAG || true
# Image with Init Process
docker manifest inspect ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$MANIFEST_INIT_TAG || true

# Push manifest list
docker manifest push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$MANIFEST_LATEST_TAG || true
# Image with Init Process
docker manifest push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:$MANIFEST_INIT_TAG || true
