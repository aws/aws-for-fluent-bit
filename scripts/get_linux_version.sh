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

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the root directory of the repository
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Path to linux.version file
LINUX_VERSION_FILE="${ROOT_DIR}/linux.version"

# Check if linux.version file exists
if [ ! -f "$LINUX_VERSION_FILE" ]; then
    echo "Error: linux.version file not found at $LINUX_VERSION_FILE" >&2
    exit 1
fi

# Extract version from linux.version using jq
# This extracts the version from the linux object
VERSION=$(jq -r '.linux.version' "$LINUX_VERSION_FILE")

# Check if jq command was successful and version is not null
if [ $? -ne 0 ] || [ "$VERSION" = "null" ] || [ -z "$VERSION" ]; then
    echo "Error: Failed to extract version from linux.version file" >&2
    exit 1
fi

# Output the version
echo "$VERSION"
