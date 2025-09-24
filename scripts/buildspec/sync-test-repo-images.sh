#!/bin/bash

# Script to sync test repo images from ECR to local Docker
# Extracted from buildspec for reusability

set -e

# Parse command line arguments
RETAG_IMAGES=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --tag)
            RETAG_IMAGES=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--tag]"
            echo "  --tag  Retag images locally as amazon/aws-for-fluent-bit instead of test repo"
            exit 1
            ;;
    esac
done

# Check required environment variables
if [[ -z "$AWS_REGION" || -z "$AWS_ACCOUNT" ]]; then
    echo "Error: AWS_REGION and AWS_ACCOUNT environment variables must be set"
    exit 1
fi

echo "Syncing test repo images from ECR to local Docker..."
echo "AWS Region: $AWS_REGION"
echo "AWS Account: $AWS_ACCOUNT"

# Enforce STS regional endpoints
export AWS_STS_REGIONAL_ENDPOINTS=regional

# Helper function to pull images with optional suffix
pull_image_set() {
    local repo_base="$1"
    local suffix="$2"
    local failed_images=()
    
    # Helper function to pull a single image
    try_pull() {
        local tag="$1"
        local full_image="${repo_base}:${tag}"
        local pull_success=true
        
        if [[ -n "$suffix" ]]; then
            # For suffixed images, capture failures but don't exit
            docker pull "$full_image" 2>/dev/null || { failed_images+=("$full_image"); pull_success=false; }
        else
            # For non-suffixed images, fail on missing images (original behavior)
            docker pull "$full_image"
        fi
        
        # Retag if --tag flag was provided and pull was successful
        if [[ "$RETAG_IMAGES" == "true" && "$pull_success" == "true" ]]; then
            local new_tag="amazon/aws-for-fluent-bit:${tag}"
            echo "Retagging $full_image -> $new_tag"
            docker tag "$full_image" "$new_tag"
        fi
    }
    
    echo "Pulling standard images${suffix:+ with suffix '$suffix'}..."
    try_pull "amd64${suffix}"
    try_pull "arm64${suffix}"
    try_pull "amd64-debug${suffix}"
    try_pull "arm64-debug${suffix}"
    
    echo "Pulling init process images${suffix:+ with suffix '$suffix'}..."
    try_pull "init-amd64${suffix}"
    try_pull "init-arm64${suffix}"
    try_pull "init-amd64-debug${suffix}"
    try_pull "init-arm64-debug${suffix}"
    
    # Report failed images if any
    if [[ ${#failed_images[@]} -gt 0 ]]; then
        if [[ -n "$suffix" ]]; then
            echo "WARNING: The following images with suffix '$suffix' were not found:"
            printf '  %s\n' "${failed_images[@]}"
        fi
        # Note: Non-suffixed failures already exited above, so this won't run for them
    fi
}

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Set up repository base URL
REPO_BASE="${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test"

# Pull images without suffix
pull_image_set "$REPO_BASE" ""

# Pull images with -3 suffix
pull_image_set "$REPO_BASE" "-3"

echo "Successfully synced test repo images to local Docker"

if [[ "$RETAG_IMAGES" == "true" ]]; then
    echo "Images have been retagged as: amazon/aws-for-fluent-bit"
    echo ""
    echo "Retagged images:"
    docker image ls amazon/aws-for-fluent-bit
else
    echo ""
    echo "Test repo images:"
    docker image ls "${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test"
fi
