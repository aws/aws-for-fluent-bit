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

import json
import os

json_data = {}

with open('../linux.version', 'r') as linux_version:
    json_data = json.load(linux_version)
    new_release_stamp = os.environ.get('AWS_FOR_FLUENT_BIT_REBUILD_VERSION')
    json_data['linux']['version'] = new_release_stamp


with open('../linux.version', 'w') as linux_version:
    linux_version.write(json.dumps(json_data, indent=4))
