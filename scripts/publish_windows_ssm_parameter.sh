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
# This script would be executed from a codebuild project which would set the following environment variables-
# ACTION -> Action to perform. Can be amongst "publish-ssm-parameters", or "sync-ssm-parameter"
# SSM_PARAM_NAMESPACE -> The SSM Parameter namespace to be used.
# ACCOUNT_ID -> Account ID where the images are present.
# REGIONS_TO_PUBLISH -> A comma separated list of regions where we need to publish SSM parameter.
# PUBLIC_REGISTRY_ALIAS -> Used when syncing the SSM params.
# PUBLIC_REPOSITORY -> Public repository which is used for the image sync.
#############################################################################################################

#############################################################################################################
# Helper methods to publish the SSM Parameter.
#############################################################################################################

# This method publishes the SSM parameter for a given tag if the same is not present or has old data.
publish_ssm_param() {
  local region param_name expected_param_value ssm_parameter old_param_value
  region=${1}
  param_name=${2}
  expected_param_value=${3}

  echo "Publishing ${param_name} in ${region} region."
  ssm_parameter=$(aws ssm get-parameter --name "${param_name}" --region "${region}" || echo "1")
  # If SSM Parameter is present then find the old value.
  if [ "$ssm_parameter" != 1 ]; then
    old_param_value=$(echo "$ssm_parameter" | jq -r '.Parameter.Value')
  fi

  # If the expected parameter is not present, or has old data, then put the same in SSM store.
  if [[ "$ssm_parameter" = 1 || "$old_param_value" != "$expected_param_value" ]]; then
    # Verify that the image manifest actually exists and then publish the parameter.
    check_image_manifest_exists "${expected_param_value}"

    aws ssm put-parameter \
    --region "${region}" \
    --name "${param_name}" \
    --overwrite \
    --description 'Regional Amazon ECR Image URI for the AWS for Fluent Bit Windows Docker Image' \
    --type String \
    --value "${expected_param_value}"

    echo "Published SSM parameter ${param_name} = ${expected_param_value} in ${region} region"
  else
    echo "SSM Parameter ${param_name} is already latest. Skipping."
  fi
}

# Publishes SSM Parameter for a given version.
publish_ssm_param_for_version(){
  local region version param_name param_value
  region=${1}
  version=${2}
  # Get the regional endpoint variable
  image_endpoint=$(get_regional_image_endpoint "${region}")

  param_name="${SSM_PARAM_NAMESPACE}/${version}-windowsservercore"
  param_value="${ACCOUNT_ID}.dkr.ecr.${region}.${image_endpoint}/aws-for-fluent-bit:${version}-windowsservercore"

  publish_ssm_param "${region}" "${param_name}" "${param_value}"
}

# Publishes SSM Parameter for the latest version.
publish_ssm_param_for_latest(){
  local region param_name expected_param_value
  region=${1}
  # Get the regional endpoint variable
  image_endpoint=$(get_regional_image_endpoint "${region}")

  param_name="${SSM_PARAM_NAMESPACE}/windowsservercore-latest"
  expected_param_value="${ACCOUNT_ID}.dkr.ecr.${region}.${image_endpoint}/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_LATEST_VERSION}-windowsservercore"

  publish_ssm_param "${region}" "${param_name}" "${expected_param_value}"
}

# Publishes SSM Parameter for the stable version.
publish_ssm_param_for_stable(){
  local region param_name expected_param_value
  region=${1}
  # Get the regional endpoint variable
  image_endpoint=$(get_regional_image_endpoint "${region}")

  param_name="${SSM_PARAM_NAMESPACE}/windowsservercore-stable"
  expected_param_value="${ACCOUNT_ID}.dkr.ecr.${region}.${image_endpoint}/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_STABLE_VERSION}-windowsservercore"

  publish_ssm_param "${region}" "${param_name}" "${expected_param_value}"
}

# Publishes the SSM Parameter for all the supported versions in a given region.
publish_to_region() {
  local region
  region=${1}

  # For a given region, iterate over all supported versions and publish them if required.
  while read -r version; do
    publish_ssm_param_for_version "${region}" "${version}"
  done <<< "$(echo "${ALL_AWS_FOR_FLUENT_BIT_VERSIONS}")"

  # Finally, publish the SSM param for latest as well as Dockerhub version.
  publish_ssm_param_for_latest $region
  publish_ssm_param_for_version "${region}" "${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}"
}

#############################################################################################################
# Helper methods for sync task
#############################################################################################################

# Compares if the image referenced by local SSM store and that in upstream repository are same.
compare_latest_ssm_param_image_with_public_ecr() {
  local region repository param_name ssm_parameter regional_ecr_image upstream_image
  region=${1}
  repository=${2}
  param_name="${SSM_PARAM_NAMESPACE}/windowsservercore-latest"
  upstream_image="${repository}:windowsservercore-latest"

  ssm_parameter=$(aws ssm get-parameter --name "${param_name}" --region "${region}" || echo "1")
  if [ "$ssm_parameter" = 1 ]; then
    return 1
  else
    regional_ecr_image=$(echo "$ssm_parameter" | jq -r '.Parameter.Value')
  fi

  compare_image_manifests "${regional_ecr_image}" "${upstream_image}"
  return $?
}

#############################################################################################################
# Start of the script
#############################################################################################################

# Source the common methods
source ./common_windows.sh

#############################################################################################################
# This action would be called in classic regions where we push the SSM parameters.
# "publish-ssm-parameters" action would publish a new SSM Parameter if same is not present.
#############################################################################################################
if [[ $ACTION == "publish-ssm-parameters" ]]; then
  echo "Publishing the SSM parameter for Windows images in regions: ${REGIONS_TO_PUBLISH}"

  # Split the comma separated list of regions into an array
  REGIONS=(`echo $REGIONS_TO_PUBLISH | sed 's/,/\n/g'`)
  for region in "${REGIONS[@]}"
  do
    # Get the regional endpoint variable
    image_endpoint=$(get_regional_image_endpoint "${region}")
    # Authenticate to ECR so that regional image manifest can be inspected.
    aws ecr get-login-password --region "${region}" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${region}.${image_endpoint}"
    publish_to_region "${region}"
  done

#############################################################################################################
# This action would be invoked in opt-in regions as well as other partitions.
# We will check if the images referenced in SSM param are same as those in public ECR.
# If not, we will update the SSM parameters with latest.
#############################################################################################################
elif [[ $ACTION == "sync-ssm-parameter" ]]; then
  # Split the comma separated list of regions into an array
  REGIONS=(`echo $REGIONS_TO_PUBLISH | sed 's/,/\n/g'`)
  for region in "${REGIONS[@]}"
  do
    # Get the regional endpoint
    image_endpoint=$(get_regional_image_endpoint "${region}")
    # Authenticate to ECR so that regional image manifest can be inspected.
    aws ecr get-login-password --region "${region}" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${region}.${image_endpoint}"

    # Publish stable parameter if it has old data.
    publish_ssm_param_for_stable "${region}"

    # For a given region, find if the sync is need for all other parameters.
    repository="public.ecr.aws/${PUBLIC_REGISTRY_ALIAS}/${PUBLIC_REPOSITORY}"
    compare_latest_ssm_param_image_with_public_ecr "${region}" "${repository}"

    # If return value is 1, then publish the SSM params in this region.
    if [ $? = 1 ]; then
      publish_to_region "${region}"
    fi
  done

#############################################################################################################
# Any action not matching above is unsupported.
#############################################################################################################
else
  echo "Unsupported action: ${ACTION}"
  exit 1
fi
