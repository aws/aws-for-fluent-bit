#!/bin/bash
# Copyright 2024 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

scripts=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${scripts}"

# If latest is a rebuild ("2.31.12.20230911") returns the base ("2.31.12")
export AWS_FOR_FLUENT_BIT_BASE_VERSION=$(cat ../AWS_FOR_FLUENT_BIT_VERSION | cut -d '.' -f 1-3)

export TODAY_DATE_STAMP=$(date +"%Y%m%d")

export AWS_FOR_FLUENT_BIT_REBUILD_VERSION="${AWS_FOR_FLUENT_BIT_BASE_VERSION}.${TODAY_DATE_STAMP}"

echo "Creating linux only image rebuild ${AWS_FOR_FLUENT_BIT_REBUILD_VERSION} for ${AWS_FOR_FLUENT_BIT_BASE_VERSION}"
echo "This will edit the version file in your project directory, next run 'make release' next to build"

echo -n ${AWS_FOR_FLUENT_BIT_REBUILD_VERSION} > ../AWS_FOR_FLUENT_BIT_VERSION

python3 linux-rebuild.py

