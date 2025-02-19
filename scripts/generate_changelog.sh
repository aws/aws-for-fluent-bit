#!/bin/bash
set -xeuo pipefail

# Initialize variables
next_token=""
all_tags=()

# Get all amazonlinux container image tags
while true; do
    if [ -z "$next_token" ]; then
        response=$(curl -sSL \
            --header "Content-Type: application/json" \
            --request POST \
            --data '{"registryAliasName":"amazonlinux","repositoryName":"amazonlinux","maxResults":250}' \
            https://api.us-east-1.gallery.ecr.aws/describeImageTags)
    else
        response=$(curl -sSL \
            --header "Content-Type: application/json" \
            --request POST \
            --data "{\"registryAliasName\":\"amazonlinux\",\"repositoryName\":\"amazonlinux\",\"nextToken\":\"$next_token\",\"maxResults\":250}" \
            https://api.us-east-1.gallery.ecr.aws/describeImageTags)
    fi

    # Extract tags and add them to the array
    tags=$(echo "$response" | jq -r '.imageTagDetails[].imageTag')
    all_tags+=($tags)

    # Check if there's a next token
    next_token=$(echo "$response" | jq -r '.nextToken')
    if [[ "$next_token" == "null" ]]; then
        break
    fi
done

# Find the most recent AL2 tag
most_recent_al2=$(printf '%s\n' "${all_tags[@]}" | grep '^2\.' | grep -v minimal | grep -v arm | grep -v amd | sort -V | tail -n 1)

# Read the JSON file
json_file="linux.version"
json_content=$(cat "$json_file")

# Extract values using jq
version=$(echo "$json_content" | jq -r '.linux.version')
fluent_bit_version=$(echo "$json_content" | jq -r '.linux."fluent-bit"')
cloudwatch_plugin_version=$(echo "$json_content" | jq -r '.linux."cloudwatch-plugin"')
kinesis_plugin_version=$(echo "$json_content" | jq -r '.linux."kinesis-plugin"')
firehose_plugin_version=$(echo "$json_content" | jq -r '.linux."firehose-plugin"')

# Generate the changelog entry
cat << EOF
### $version
This release includes:
* Fluent Bit [$fluent_bit_version](https://github.com/fluent/fluent-bit/tree/v$fluent_bit_version)
* Amazon CloudWatch Logs for Fluent Bit ${cloudwatch_plugin_version#v}
* Amazon Kinesis Streams for Fluent Bit ${kinesis_plugin_version#v}
* Amazon Kinesis Firehose for Fluent Bit ${firehose_plugin_version#v}
* Amazon Linux base container image version: $most_recent_al2

Compared to the previous release, this release adds:
* Fix - TODO blah blah [#TODO](https://github.com/amazon-contributing/upstream-to-fluent-bit/pull/TODO)
* Enhancement - TODO blah blah [#TODO](https://github.com/aws/aws-for-fluent-bit/pull/TODO)
EOF
