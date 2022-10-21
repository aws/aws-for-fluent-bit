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
# This script would be executed from a codebuild project which would set the following environment variables-
# ACTION -> Action to perform. Can be amongst "verify-ssm-parameter"
# SSM_PARAM_NAMESPACE -> The SSM Parameter namespace to be used.
# ACCOUNT_ID -> Account ID where the images are present.
# REGIONS_TO_PUBLISH -> A comma separated list of regions where we need to publish SSM parameter.
#############################################################################################################

#############################################################################################################
# Helper methods to verify the SSM Parameter.
#############################################################################################################

# Verifies that the given param tag has the expected image in the given region and account.
verify_ssm_param(){
  local ssm_parameter region version param_name
  region=${1}
  version=${2}
  param_tag=${3}

  # Get the regional endpoint variable
  image_endpoint=$(get_regional_image_endpoint "${region}")

  # Get the parameter name and the expected parameter value.
  param_name="${SSM_PARAM_NAMESPACE}/${param_tag}"
  expected_param_value="${ACCOUNT_ID}.dkr.ecr.${region}.${image_endpoint}/aws-for-fluent-bit:${version}-windowsservercore"

  echo "Verifying ${param_name} in ${region} region. Expected value: ${expected_param_value}"
  ssm_parameter=$(aws ssm get-parameter --name "${param_name}" --region "${region}" || echo "1")
  # If SSM Parameter is present then find the old value.
  if [ "$ssm_parameter" != 1 ]; then
    current_param_value=$(echo $ssm_parameter | jq -r '.Parameter.Value')
  fi

  # If the latest parameter is not present, or is different then we exit with failure code.
  if [[ "$current_param_value" == "$expected_param_value" ]]; then
    echo "SSM parameter ${param_name} in ${region} region matches the expected value"
  else
    echo "SSM parameter verification of ${param_name} in ${region} region failed. Actual: ${current_param_value} : Expected: ${expected_param_value}"
    exit 1
  fi
}

#############################################################################################################
# Start of the script
#############################################################################################################

# Source the common methods
source ./common_windows.sh

#############################################################################################################
# If action is "verify-ssm-parameter" then verify that SSM parameter for each supported version is present.
#############################################################################################################
if [[ $ACTION == "verify-ssm-parameter" ]]; then
  echo "Verifying the SSM parameter for Windows images in region: ${REGIONS_TO_PUBLISH}"

  # Split the comma separated list of regions into an array
  REGIONS=(`echo $REGIONS_TO_PUBLISH | sed 's/,/\n/g'`)
  for region in "${REGIONS[@]}"
  do
    # For a given region, iterate over all supported versions and verify the SSM parameters.
    while read -r version; do
        verify_ssm_param "${region}" "${version}" "${version}-windowsservercore"
    done <<< "$(echo "${ALL_AWS_FOR_FLUENT_BIT_VERSIONS}")"

    # Finally, verify the SSM param for latest as well as Dockerhub version.
    verify_ssm_param "${region}" "${AWS_FOR_FLUENT_BIT_LATEST_VERSION}" "windowsservercore-latest"
    verify_ssm_param "${region}" "${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}" "${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}-windowsservercore"
    verify_ssm_param "${region}" "${AWS_FOR_FLUENT_BIT_LATEST_VERSION}" "windowsservercore-latest"
  done

#############################################################################################################
# Any action not matching above is unsupported.
#############################################################################################################
else
  echo "Unsupported action: ${ACTION}"
  exit 1
fi
