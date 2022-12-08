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
# Helper methods to set the required variables.
#############################################################################################################
# Constant
# Number of presently supported OS versions.
SUPPORTED_WINDOWS_OS_RELEASES_NUMBER=2

# Sets ALL_AWS_FOR_FLUENT_BIT_VERSIONS variable with all the supported fluent-bit versions.
set_all_supported_versions() {
  ALL_AWS_FOR_FLUENT_BIT_VERSIONS=$(cat < ../windows.versions | jq -c -r '.windows[].version')
}

# Sets AWS_FOR_FLUENT_BIT_STABLE_VERSION variable with the stable version.
set_stable_version() {
  # Find the stable version.
  AWS_FOR_FLUENT_BIT_STABLE_VERSION=$(cat < ../windows.versions | jq -r '.windows[] | select(.stable==true)| .version')
  STABLE_VERSION_COUNT=$(echo "$AWS_FOR_FLUENT_BIT_STABLE_VERSION" | wc -l)

  if [ "$STABLE_VERSION_COUNT" -ne 1 ]; then
    echo "Discrepancy in stable version: ${AWS_FOR_FLUENT_BIT_STABLE_VERSION}"
    exit 1
  fi
}

# Sets AWS_FOR_FLUENT_BIT_LATEST_VERSION variable with the latest version.
set_latest_version() {
  # Find the latest version.
  AWS_FOR_FLUENT_BIT_LATEST_VERSION=$(cat < ../windows.versions | jq -r '.windows[] | select(.latest==true)| .version')
  LATEST_VERSION_COUNT=$(echo "$AWS_FOR_FLUENT_BIT_LATEST_VERSION" | wc -l)

  if [ "$LATEST_VERSION_COUNT" -ne 1 ]; then
    echo "Discrepancy in latest version: ${AWS_FOR_FLUENT_BIT_LATEST_VERSION}"
    exit 1
  fi
}

# Sets AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB variable with the latest version available in dockerhub.
set_dockerhub_version() {
  # Find the dockerhub version.
  docker_hub_image_tags=$(curl -s -S 'https://registry.hub.docker.com/v2/repositories/amazon/aws-for-fluent-bit/tags/?page=1&page_size=250' | jq -r '.results[].name')
  tag_array=(`echo ${docker_hub_image_tags}`)
  AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB=$(./get_latest_dockerhub_version.py windows ${tag_array[@]})
}

# Returns the regional endpoint.
# For Standard partition, it would be "amazonaws.com"
# For China partition, it would be "amazonaws.com.cn"
get_regional_image_endpoint() {
  region=${1}
  endpoint="amazonaws.com"

  if [ "${region}" = "cn-north-1" ] || [ "${region}" = "cn-northwest-1" ]; then
  		endpoint="${endpoint}.cn"
  fi
  echo "${endpoint}"
}

#############################################################################################################
# Functions to compare and validate image manifests
#############################################################################################################

# Checks if the image manifest for the provided image exists in the region.
check_image_manifest_exists() {
  manifest_image=${1}

  # Inspect the manifest of the image.
  # If the same doesn't exist, return 1.
  image_manifest=$(docker manifest inspect "${manifest_image}" || echo "1")

  if [ "${image_manifest}" = 1 ]; then
    echo "No manifest found for ${manifest_image}"
    exit 1
  else
    # If the image manifest exists, then ensure that the number of digests is equal to the supported Windows releases.
    manifest_digests=$(echo "${image_manifest}" | jq -r '.manifests[].digest')
    if [ $(echo "${manifest_digests}" | wc -l) != $SUPPORTED_WINDOWS_OS_RELEASES_NUMBER ]; then
      echo "Incomplete manifest found for ${manifest_image}"
      exit 1
    fi
    echo "Manifest validation completed for ${manifest_image}"
  fi
}

# Compares image manifests of two images based on the image digests.
compare_image_manifests() {
  first_manifest_image=${1}
  second_manifest_image=${2}

  # Retrieve the manifests of both the images. If the same is not found then return 1.
  first_manifest=$(docker manifest inspect "${first_manifest_image}" || echo "1")
  second_manifest=$(docker manifest inspect "${second_manifest_image}" || echo "1")

  if [ "${first_manifest}" = 1 ]; then
    echo "No manifest found for ${first_manifest_image}"
    return 1
  elif [ "${second_manifest}" = 1 ]; then
    echo "No manifest found for ${second_manifest_image}"
    return 1
  fi

  # Obtain the digest entries from the manifest.
  first_manifest_digests=$(echo "${first_manifest}" | jq -r '.manifests[].digest' | sort)
  second_manifest_digests=$(echo "${second_manifest}" | jq -r '.manifests[].digest' | sort)

  # Compare the digest entries of both the manifests.
  if [ $(echo "$first_manifest_digests" | wc -l) != $(echo "$second_manifest_digests" | wc -l) ]; then
    echo "Mismatch in manifests due to different number of manifest entries"
    return 1
  elif ! diff <(echo "${first_manifest_digests}") <(echo "${second_manifest_digests}"); then
    echo "Mismatch in manifests: First: ${first_manifest_digests}, Second: ${second_manifest_digests}"
    return 1
  else
    echo "Manifests are same"
  fi
}

# Set the required variables
set_all_supported_versions
set_latest_version
set_dockerhub_version
set_stable_version
