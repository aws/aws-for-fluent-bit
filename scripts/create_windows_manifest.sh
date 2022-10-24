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
image_endpoint=$(get_regional_image_endpoint "${AWS_REGION}")

# Declare constants
export DOCKER_CLI_EXPERIMENTAL=enabled
declare -A os_releases=( ["windows2019"]="ltsc2019" ["windows2022"]="ltsc2022")

#############################################################################################################
# Login into regional ECR of the region where we want to push the manifest.
# We also generate the Repository path here specific to regional ECR.
#############################################################################################################
if [[ $REGISTRY_TO_PUSH == "private-ecr" ]]; then
  # Create Repository path specific for private ECR.
  REGISTRY="${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.${image_endpoint}"
  REPOSITORY_PATH="${REGISTRY}/${REPOSITORY}"

  # Login into ECR of the region.
  aws ecr get-login-password --region ${AWS_REGION}| docker login --username AWS --password-stdin ${REGISTRY}

#############################################################################################################
# Login into public ECR of the account where we want to push the manifest.
# In order to do so, we assume a cross-account IAM role.
# We also generate the Repository path here specific to public ECR.
#############################################################################################################
elif [[ $REGISTRY_TO_PUSH == "public-ecr" ]]; then
  # Create Repository path specific for public ECR.
  REGISTRY="public.ecr.aws/${PUBLIC_REGISTRY_ALIAS}"
  REPOSITORY_PATH="${REGISTRY}/${REPOSITORY}"

  # Assume the publish role for public ecr.
  CREDS=`aws sts assume-role --role-arn ${PUBLISH_ROLE_ARN_PUBLIC_ECR} --role-session-name publicECR`
  export AWS_ACCESS_KEY_ID=`echo $CREDS | jq -r .Credentials.AccessKeyId`
  export AWS_SECRET_ACCESS_KEY=`echo $CREDS | jq -r .Credentials.SecretAccessKey`
  export AWS_SESSION_TOKEN=`echo $CREDS | jq -r .Credentials.SessionToken`

  # Login into public ECR
  aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${REGISTRY}

#############################################################################################################
# Login into dockerhub account where we want to push the manifest.
# In order to do so, we get the credentials stored in Secrets Manager.
# We also generate the Repository path here specific to dockerhub.
#############################################################################################################
elif [[ $REGISTRY_TO_PUSH == "dockerhub" ]]; then
  # Create Repository path specific for Dockerhub.
  REPOSITORY_PATH="${REPOSITORY}"

  # Login into dockerhub account
  DOCKER_HUB_SECRET="com.amazonaws.dockerhub.aws-for-fluent-bit.credentials"
  docker login \
  -u "$(aws secretsmanager get-secret-value --secret-id $DOCKER_HUB_SECRET --region us-west-2 | jq -r '.SecretString | fromjson.username')" \
  --password "$(aws secretsmanager get-secret-value --secret-id $DOCKER_HUB_SECRET --region us-west-2 | jq -r '.SecretString | fromjson.password')"

#############################################################################################################
# Other registries are not supported.
#############################################################################################################
else
  echo "Unsupported registry: ${REGISTRY_TO_PUSH}"
  exit 1
fi

#############################################################################################################
# "create-manifest" action is used to create and push manifests for Windows in the target region and account.
#############################################################################################################
if [[ $ACTION == "create-manifest" ]]; then

  # Create and push the image manifests for all the versions.
  while read -r version; do
    # Create image manifest.
    docker manifest create ${REPOSITORY_PATH}:${version}-windowsservercore \
    ${REPOSITORY_PATH}:${version}-${os_releases[windows2019]} \
    ${REPOSITORY_PATH}:${version}-${os_releases[windows2022]}
    if [ $? = 1 ]; then
      echo "Failed to create manifest for ${REPOSITORY_PATH}:${version}-windowsservercore"
      exit 1
    fi

    # Sanity check the manifest.
    docker manifest inspect ${REPOSITORY_PATH}:${version}-windowsservercore

    # Push manifest to ECR.
    docker manifest push ${REPOSITORY_PATH}:${version}-windowsservercore
    if [ $? = 1 ]; then
      echo "Failed to push manifest ${REPOSITORY_PATH}:${version}-windowsservercore"
      exit 1
    fi
  done <<< "$(echo "${ALL_AWS_FOR_FLUENT_BIT_VERSIONS}")"

  # Create manifest for latest image.
  docker manifest create ${REPOSITORY_PATH}:windowsservercore-latest \
  ${REPOSITORY_PATH}:${AWS_FOR_FLUENT_BIT_LATEST_VERSION}-${os_releases[windows2019]} \
  ${REPOSITORY_PATH}:${AWS_FOR_FLUENT_BIT_LATEST_VERSION}-${os_releases[windows2022]}
  if [ $? = 1 ]; then
    echo "Failed to create manifest for ${REPOSITORY_PATH}:windowsservercore-latest"
    exit 1
  fi

  # Push manifest for latest image.
  docker manifest push ${REPOSITORY_PATH}:windowsservercore-latest
  if [ $? = 1 ]; then
    echo "Failed to push manifest ${REPOSITORY_PATH}:windowsservercore-latest"
    exit 1
  fi

#############################################################################################################
# "sync-stable-image" action is used to sync stable image in target repository/region/account.
#############################################################################################################
elif [[ $ACTION == "sync-stable-image" ]]; then
  # Obtain the image URLs for expected and actual stable Windows image.
  EXPECTED_IMAGE_FOR_STABLE="${REPOSITORY_PATH}:${AWS_FOR_FLUENT_BIT_STABLE_VERSION}-windowsservercore"
  ACTUAL_IMAGE_FOR_STABLE="${REPOSITORY_PATH}:windowsservercore-stable"

  # If the image manifests are not same then create and push the latest one.
  compare_image_manifests "${EXPECTED_IMAGE_FOR_STABLE}" "${ACTUAL_IMAGE_FOR_STABLE}"
  if [ $? = 1 ]; then
      # Create manifest for stable image.
      docker manifest create ${REPOSITORY_PATH}:windowsservercore-stable \
      ${REPOSITORY_PATH}:${AWS_FOR_FLUENT_BIT_STABLE_VERSION}-${os_releases[windows2019]} \
      ${REPOSITORY_PATH}:${AWS_FOR_FLUENT_BIT_STABLE_VERSION}-${os_releases[windows2022]}

      # Push manifest for stable image.
      docker manifest push ${REPOSITORY_PATH}:windowsservercore-stable
      if [ $? = 1 ]; then
        echo "Failed to push manifest ${REPOSITORY_PATH}:windowsservercore-stable"
        exit 1
      fi
      echo "Synced the latest version of stable image"
  else
    echo "Stable image is already in sync"
  fi
#############################################################################################################
# Any other action is not supported.
#############################################################################################################
else
  echo "Unsupported action: ${ACTION}"
  exit 1
fi
