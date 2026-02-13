#!/bin/bash
# Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

set -xeuo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPTS_DIR}/.." && pwd)"

# linux.version file
LINUX_VERSION_FILE="${ROOT}/linux.version"

# Check if linux.version file exists
if [ ! -f "$LINUX_VERSION_FILE" ]; then
    echo "Error: linux.version file not found at $LINUX_VERSION_FILE" >&2
    exit 1
fi

# Check required parameters
if [ $# -lt 2 ]; then
    echo "Usage: $0 <BUILD_VERSION> <FIELD>" >&2
    echo "Example: $0 2 version" >&2
    echo "Example: $0 3 al-tag" >&2
    exit 1
fi

BUILD_VERSION=$1
FIELD=$2

# Function to get version info from linux.version based on BUILD_VERSION
get_version_info() {
    local build_version=$1
    local field=$2
    
    # Extract info for the specific major-version
    jq -r ".[] | select(.linux.\"major-version\" == \"$build_version\") | .linux.\"$field\"" "$LINUX_VERSION_FILE"
}

# Extract the requested field from linux.version using jq for the specified BUILD_VERSION
VALUE=$(get_version_info "$BUILD_VERSION" "$FIELD")

# Check if jq command was successful and value is not null
if [ $? -ne 0 ] || [ "$VALUE" = "null" ] || [ -z "$VALUE" ]; then
    echo "Error: Failed to extract $FIELD for BUILD_VERSION=$BUILD_VERSION from linux.version file" >&2
    exit 1
fi

# Output the value
echo "$VALUE"
