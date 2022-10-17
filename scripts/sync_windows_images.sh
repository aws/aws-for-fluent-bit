#!/bin/bash
# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

set -uo pipefail

#############################################################################################################
# Start of the script
#############################################################################################################

# Source the common methods
source ./common_windows.sh
# Get the regional endpoint variable
image_endpoint=$(get_regional_image_endpoint "${TARGET_AWS_REGION}")

# Declare the constants
SOURCE_REPOSITORY_URL="public.ecr.aws/${SOURCE_REGISTRY_ALIAS}/${SOURCE_REPOSITORY}"
TARGET_REPOSITORY_URL="${TARGET_AWS_ACCOUNT}.dkr.ecr.${TARGET_AWS_REGION}.${image_endpoint}/${TARGET_REPOSITORY}"

# Authenticate to ECR of target repository.
# Since out sync-task workflows would only target regional ECR, we are explicitly logging into the same.
aws ecr get-login-password --region "${TARGET_AWS_REGION}" | docker login --username AWS --password-stdin "${TARGET_REPOSITORY_URL}"

echo "Verifying if the images need to be synced in: ${TARGET_AWS_REGION}@${TARGET_AWS_ACCOUNT}"

# Obtain the source image and expected image url.
LATEST_IMAGE_URI_WITH_LATEST_TAG_IN_SOURCE="${SOURCE_REPOSITORY_URL}:windowsservercore-latest"
LATEST_IMAGE_URI_WITH_LATEST_TAG_IN_TARGET="${TARGET_REPOSITORY_URL}:windowsservercore-latest"

# Compare manifests for both and determine if sync is required.
compare_image_manifests "${LATEST_IMAGE_URI_WITH_LATEST_TAG_IN_SOURCE}" "${LATEST_IMAGE_URI_WITH_LATEST_TAG_IN_TARGET}"
if [ $? = 1 ]; then
  echo "true" > SYNC_IMAGES
  echo "Images need to be synced in: ${TARGET_AWS_REGION}@${TARGET_AWS_ACCOUNT}"
else
  echo "false" > SYNC_IMAGES
  echo "Images are already in sync: ${TARGET_AWS_REGION}@${TARGET_AWS_ACCOUNT}"
fi
