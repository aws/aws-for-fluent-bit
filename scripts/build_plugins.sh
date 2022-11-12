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
  "OS_TYPE"
)

# A variable to hold the build arguments for docker build
PLUGIN_BUILD_ARGS=""

# windows or linux
# set by env var in Makefile right now
OS_TYPE="${OS_TYPE}"

# Go plugin versions can either be set by args to the script, or they will be sourced
# from the windows.versions or linux.version file
KINESIS_PLUGIN_TAG=""
FIREHOSE_PLUGIN_TAG=""
CLOUDWATCH_PLUGIN_TAG=""

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
#TODO: this bash does not actually work on Developer Macs for some reason
while [ $# -gt 0 ]
do
  case "$1" in
    --KINESIS_PLUGIN_CLONE_URL)
      if [ -n "$2" ];then PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg KINESIS_PLUGIN_CLONE_URL=$2";fi
      shift 2;;
    --KINESIS_PLUGIN_TAG)
      if [ -n "$2" ];then
        PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg KINESIS_PLUGIN_TAG=$2"
        KINESIS_PLUGIN_TAG="$2"
      fi
      shift 2;;
    --KINESIS_PLUGIN_BRANCH)
      if [ -n "$2" ];then PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg KINESIS_PLUGIN_BRANCH=$2";fi
      shift 2;;
    --FIREHOSE_PLUGIN_CLONE_URL)
      if [ -n "$2" ];then PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg FIREHOSE_PLUGIN_CLONE_URL=$2";fi
      shift 2;;
    --FIREHOSE_PLUGIN_TAG)
      if [ -n "$2" ];then
        PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg FIREHOSE_PLUGIN_TAG=$2"
        FIREHOSE_PLUGIN_TAG="$2"
      fi
      shift 2;;
    --FIREHOSE_PLUGIN_BRANCH)
      if [ -n "$2" ];then PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg FIREHOSE_PLUGIN_BRANCH=$2";fi
      shift 2;;
    --CLOUDWATCH_PLUGIN_CLONE_URL)
      if [ -n "$2" ];then PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg CLOUDWATCH_PLUGIN_CLONE_URL=$2";fi
      shift 2;;
    --CLOUDWATCH_PLUGIN_TAG)
      if [ -n "$2" ];then
        PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg CLOUDWATCH_PLUGIN_TAG=$2"
        CLOUDWATCH_PLUGIN_TAG="$2"
      fi
      shift 2;;
    --CLOUDWATCH_PLUGIN_BRANCH)
      if [ -n "$2" ];then PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg CLOUDWATCH_PLUGIN_BRANCH=$2";fi
      shift 2;;
    # End of arguments. End here and break.
    --) shift; break ;;
    # Any other argument is an invalid arg.
    *) usage;;
  esac
done

# Change the directory to root of the repository
scripts=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${scripts}/.."

if [ -z "$OS_TYPE" ];
then
  echo "OS_TYPE is required"
  exit 1
fi

# Sanity check that latest windows version is at top of list
if [ "$OS_TYPE" == "windows" ];
then
  is_latest=$(cat windows.versions | jq -r '.windows[0].latest')
  if [ "$is_latest" == "null" ];
  then
    echo "Latest Windows Release MUST be at the top/first element of windows.versions file"
    exit 1
  fi
fi

# Source go plugin versions from files if not set
if [ "$OS_TYPE" == "windows" ];
then
  if [ -z "$KINESIS_PLUGIN_TAG" ];
  then 
    KINESIS_PLUGIN_TAG=$(cat windows.versions | jq -r '.windows[0]."kinesis-plugin"')
    PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg KINESIS_PLUGIN_TAG=$KINESIS_PLUGIN_TAG"
  fi
  if [ -z "$FIREHOSE_PLUGIN_TAG" ];
  then 
    FIREHOSE_PLUGIN_TAG=$(cat windows.versions | jq -r '.windows[0]."firehose-plugin"')
    PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg FIREHOSE_PLUGIN_TAG=$FIREHOSE_PLUGIN_TAG"
  fi
  if [ -z "$CLOUDWATCH_PLUGIN_TAG" ];
  then 
    CLOUDWATCH_PLUGIN_TAG=$(cat windows.versions | jq -r '.windows[0]."cloudwatch-plugin"')
    PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg CLOUDWATCH_PLUGIN_TAG=$CLOUDWATCH_PLUGIN_TAG"
  fi
fi

if [ "$OS_TYPE" == "linux" ];
then
  if [ -z "$KINESIS_PLUGIN_TAG" ];
  then 
    KINESIS_PLUGIN_TAG=$(cat linux.version | jq -r '.linux."kinesis-plugin"')
    PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg KINESIS_PLUGIN_TAG=$KINESIS_PLUGIN_TAG"
  fi
  if [ -z "$FIREHOSE_PLUGIN_TAG" ];
  then 
    FIREHOSE_PLUGIN_TAG=$(cat linux.version | jq -r '.linux."firehose-plugin"')
    PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg FIREHOSE_PLUGIN_TAG=$FIREHOSE_PLUGIN_TAG"
  fi
  if [ -z "$CLOUDWATCH_PLUGIN_TAG" ];
  then 
    CLOUDWATCH_PLUGIN_TAG=$(cat linux.version | jq -r '.linux."cloudwatch-plugin"')
    PLUGIN_BUILD_ARGS="$PLUGIN_BUILD_ARGS --build-arg CLOUDWATCH_PLUGIN_TAG=$CLOUDWATCH_PLUGIN_TAG"
  fi
fi

echo "Plugin build arguments are: $PLUGIN_BUILD_ARGS"
echo "OS_TYPE=${OS_TYPE}"

if [ "$OS_TYPE" == "windows" ];
then
  # Create the build output folder
  mkdir -p ./build/windows
  echo "Created build output folder"

  # Build plugin image and then copy the windows plugins
  docker build $PLUGIN_BUILD_ARGS --no-cache -t aws-fluent-bit-plugins:latest -f ./Dockerfile.plugins-windows .
  docker create -ti --name plugin-build-container aws-fluent-bit-plugins:latest bash
  docker cp plugin-build-container:/plugins_windows.tar ./build/windows/plugins_windows.tar
  docker rm -f plugin-build-container
  echo "Copied plugin archive to the build output folder"
fi

if [ "$OS_TYPE" == "linux" ];
then
  docker build $PLUGIN_BUILD_ARGS --no-cache -t aws-fluent-bit-plugins:latest -f ./Dockerfile.plugins .
fi

