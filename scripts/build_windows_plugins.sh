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

# List of arguments the script can accept
ARGUMENT_LIST=(
  "KINESIS_PLUGIN_CLONE_URL"
  "KINESIS_PLUGIN_TAG"
  "KINESIS_PLUGIN_BRANCH"
  "FIREHOSE_PLUGIN_CLONE_URL"
  "FIREHOSE_PLUGIN_TAG"
  "FIREHOSE_PLUGIN_BRANCH"
  "CLOUDWATCH_PLUGIN_CLONE_URL"
  "CLOUDWATCH_PLUGIN_TAG"
  "CLOUDWATCH_PLUGIN_BRANCH"
)

# A variable to hold the build arguments for docker build
PLUGIN_BUILD_ARGS=""

# Method to display usage of the script
usage() {
  echo "Usage: $0 [--KINESIS_PLUGIN_CLONE_URL <string>] [--KINESIS_PLUGIN_TAG <string>] [--KINESIS_PLUGIN_BRANCH <string>]\
  [--FIREHOSE_PLUGIN_CLONE_URL <string>] [--FIREHOSE_PLUGIN_TAG <string>] [--FIREHOSE_PLUGIN_BRANCH <string>]\
  [--CLOUDWATCH_PLUGIN_CLONE_URL <string>] [--CLOUDWATCH_PLUGIN_TAG <string>] [--CLOUDWATCH_PLUGIN_BRANCH <string>]" 1>&2;
  exit 1;
}

# Read arguments
opts=$(getopt \
  --longoptions "$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
  --name "$(basename "$0")" \
  --options "" \
  -- "$@"
)

eval set -- "$opts"

# Build plugin build arguments
while [ $# -gt 0 ]
do
  case "$1" in
    --KINESIS_PLUGIN_CLONE_URL)
      PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg KINESIS_PLUGIN_CLONE_URL=$2"
      shift 2;;
    --KINESIS_PLUGIN_TAG)
      PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg KINESIS_PLUGIN_TAG=$2"
      shift 2;;
    --KINESIS_PLUGIN_BRANCH)
      PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg KINESIS_PLUGIN_BRANCH=$2"
      shift 2;;
    --FIREHOSE_PLUGIN_CLONE_URL)
      PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg FIREHOSE_PLUGIN_CLONE_URL=$2"
      shift 2;;
    --FIREHOSE_PLUGIN_TAG)
      PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg FIREHOSE_PLUGIN_TAG=$2"
      shift 2;;
    --FIREHOSE_PLUGIN_BRANCH)
      PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg FIREHOSE_PLUGIN_BRANCH=$2"
      shift 2;;
    --CLOUDWATCH_PLUGIN_CLONE_URL)
      PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg CLOUDWATCH_PLUGIN_CLONE_URL=$2"
      shift 2;;
    --CLOUDWATCH_PLUGIN_TAG)
      PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg CLOUDWATCH_PLUGIN_TAG=$2"
      shift 2;;
    --CLOUDWATCH_PLUGIN_BRANCH)
      PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg CLOUDWATCH_PLUGIN_BRANCH=$2"
      shift 2;;
    # End of arguments. End here and break.
    --) shift; break ;;
    # Any other argument is an invalid arg.
    *) usage;;
  esac
done

echo "Plugin build arguments are: $PLUGIN_BUILD_ARGS"

# Change the directory to root of the repository
scripts=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${scripts}/.."

# Create the build output folder
mkdir -p ./build/windows
echo "Created build output folder"

# Build plugin image and then copy the windows plugins
docker build $PLUGIN_BUILD_ARGS --no-cache -t aws-fluent-bit-plugins:latest -f ./Dockerfile.plugins .
docker create -ti --name plugin-build-container aws-fluent-bit-plugins:latest bash
docker cp plugin-build-container:/plugins_windows.tar ./build/windows/plugins_windows.tar
docker rm -f plugin-build-container
echo "Copied plugin archive to the build output folder"
