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

# Script to sync test repo images from ECR to local Docker
# Extracted from buildspec for reusability

set -euo pipefail

# Helper function to pull and optionally retag a single image
pull_and_retag_image() {
    local tag="$1"
    local suffix="$2"
    local allow_failure="$3"
    
    local full_tag="${tag}${suffix}"
    local full_image="${REPO_BASE}:${full_tag}"
    
    echo "Pulling ${full_image}..."
    
    if docker pull "$full_image" 2>/dev/null; then
        # Retag if --tag flag was provided
        if [[ "$RETAG_IMAGES" == "true" ]]; then
            local new_tag="amazon/aws-for-fluent-bit:${full_tag}"
            echo "Retagging $full_image -> $new_tag"
            docker tag "$full_image" "$new_tag"
        fi
        return 0
    else
        # Pull failed
        if [[ "$allow_failure" == "true" ]]; then
            echo "Warning: Failed to pull ${full_image}"
            return 1
        else
            echo "Error: Failed to pull ${full_image}"
            exit 1
        fi
    fi
}

# Helper function to pull images with optional suffix
pull_image_set() {
    local suffix="$1"
    local allow_failure="$2"
    local failed_images=()
    
    echo "Pulling standard images${suffix:+ with suffix \"$suffix\"}..."
    for tag in "${STANDARD_TAGS[@]}"; do
        if ! pull_and_retag_image "$tag" "$suffix" "$allow_failure"; then
            failed_images+=("${tag}${suffix}")
        fi
    done
    
    echo "Pulling init process images${suffix:+ with suffix \"$suffix\"}..."
    for tag in "${INIT_TAGS[@]}"; do
        if ! pull_and_retag_image "$tag" "$suffix" "$allow_failure"; then
            failed_images+=("${tag}${suffix}")
        fi
    done
    
    if [[ ${#failed_images[@]} -gt 0 && "$allow_failure" == "true" ]]; then
        echo "Warning: The following images with suffix \"$suffix\" failed to pull:"
        printf '  %s\n' "${failed_images[@]}"
    fi
}

main() {
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

    # Login to ECR
    echo "Logging into ECR..."
    aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"

    # Set up repository base URL
    REPO_BASE="${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test"

    # Define image tags to pull
    STANDARD_TAGS=("amd64" "arm64" "amd64-debug" "arm64-debug")
    INIT_TAGS=("init-amd64" "init-arm64" "init-amd64-debug" "init-arm64-debug")

    # Get VERSION for BUILD_VERSION=2
    VERSION_2=$(./scripts/get_linux_version.sh "2" "version")
    echo "Pulling images for BUILD_VERSION=2 (VERSION=${VERSION_2})..."
    pull_image_set "-${VERSION_2}" "false"

    # Get VERSION for BUILD_VERSION=3
    VERSION_3=$(./scripts/get_linux_version.sh "3" "version")
    echo "Pulling images for BUILD_VERSION=3 (VERSION=${VERSION_3})..."
    pull_image_set "-${VERSION_3}" "true"

    echo "Successfully synced test repo images to local Docker"

    if [[ "$RETAG_IMAGES" == "true" ]]; then
        printf "Images have been retagged as: amazon/aws-for-fluent-bit\n\nRetagged images:\n"
        docker image ls amazon/aws-for-fluent-bit
    else
        printf "\nTest repo images:\n"
        docker image ls "${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test"
    fi
}

# Execute main function with all script arguments
main "$@"
