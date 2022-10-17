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

set -euo pipefail

#############################################################################################################
# Start of the script
#############################################################################################################

# Source the common methods
source ./common_windows.sh
# Get the regional endpoint variable
image_endpoint=$(get_regional_image_endpoint "${AWS_REGION}")

#############################################################################################################
# For regional ECR, we create the specific image URL here. Additionally, we also authenticate to regional ECR.
#############################################################################################################
if [[ $TARGET_REGISTRY == "private-ecr" ]]; then
  # Create Repository url specific for regional ECR.
  REGISTRY="${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.${image_endpoint}"
  REPOSITORY_PATH="${REGISTRY}/${REPOSITORY}"

  # Authenticate to ECR.
  aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${REGISTRY}"

#############################################################################################################
# For public ECR, we create the specific image URL here.
#############################################################################################################
elif [[ $TARGET_REGISTRY == "public-ecr" ]]; then
  REGISTRY="public.ecr.aws/${PUBLIC_REGISTRY_ALIAS}"
  REPOSITORY_PATH="${REGISTRY}/${REPOSITORY}"

#############################################################################################################
# For dockerhub, we create the specific image URL here.
#############################################################################################################
elif [[ $TARGET_REGISTRY == "dockerhub" ]]; then
  REPOSITORY_PATH="${REPOSITORY}"
fi

#############################################################################################################
# For "verify-images" action, we will verify that the image manifest exists for all the supported versions
# in the target registry. We will also verify the latest image and compare the image digests for the same.
#############################################################################################################
if [[ $ACTION == "verify-images" ]]; then
  # Validate that manifest exists for all the versions.
  while read -r version; do
    check_image_manifest_exists "${REPOSITORY_PATH}:${version}-windowsservercore"
  done <<< "$(echo "${ALL_AWS_FOR_FLUENT_BIT_VERSIONS}")"

  # Validate that latest manifest is same as the required version.
  LATEST_IMAGE_URI_WITH_VERSION_TAG="${REPOSITORY_PATH}:${AWS_FOR_FLUENT_BIT_LATEST_VERSION}-windowsservercore"
  LATEST_IMAGE_URI_WITH_LATEST_TAG="${REPOSITORY_PATH}:windowsservercore-latest"
  compare_image_manifests "${LATEST_IMAGE_URI_WITH_LATEST_TAG}" "${LATEST_IMAGE_URI_WITH_VERSION_TAG}"

#############################################################################################################
# Any action not matching above is unsupported.
#############################################################################################################
else
  echo "Unsupported action: ${ACTION}"
  exit 1
fi
