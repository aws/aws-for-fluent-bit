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

export DOCKER_CLI_EXPERIMENTAL=enabled
declare -A os_releases=( ["windows2019"]="ltsc2019" ["windows2022"]="ltsc2022")

# Push the image to ECR with corresponding architecture as the tag.
aws ecr get-login-password --region ${AWS_REGION}| docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Find the applicable windows versions.
cd $CODEBUILD_SRC_DIR
versions=$(cat windows.versions | jq -c -r '.windows[].version')
latest_version=""

# Create and push the image manifests.
while read -r version; do
  if [[ "$latest_version" < "$version" ]]; then
    latest_version=$version
  fi

  docker manifest create ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY}:${version}-windowsservercore \
  ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY}:${version}-${os_releases[windows2019]} \
  ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY}:${version}-${os_releases[windows2022]}

  # Sanity check the manifest.
  docker manifest inspect ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY}:${version}-windowsservercore

  # Push manifest to ECR.
  docker manifest push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY}:${version}-windowsservercore
done <<< "$(echo "$versions")"

# Create and push manifest for latest image.
docker manifest create ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY}:windowsservercore-latest \
${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY}:${latest_version}-${os_releases[windows2019]} \
${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY}:${latest_version}-${os_releases[windows2022]}

docker manifest push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY}:windowsservercore-latest

# Create and push manifest for stable image.
stable_version=$(cat AWS_FOR_FLUENT_BIT_STABLE_VERSION)
docker manifest create ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY}:windowsservercore-stable \
${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY}:${stable_version}-${os_releases[windows2019]} \
${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY}:${stable_version}-${os_releases[windows2022]}

docker manifest push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY}:windowsservercore-stable
