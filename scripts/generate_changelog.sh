#!/bin/bash
set -euo pipefail

# Function to get the latest version for a specific AL version using Public ECR API
get_latest_al_version() {
    local version_prefix="$1"

    # Use Public ECR Gallery API with curl and sort by imagePushedAt timestamp
    local response=$(curl -sSL \
        --header "Content-Type: application/json" \
        --request POST \
        --data '{"registryAliasName":"amazonlinux","repositoryName":"amazonlinux","maxResults":1000}' \
        https://api.us-east-1.gallery.ecr.aws/describeImageTags)
    
    # Use jq to filter by prefix, exclude variants, sort by version, and get the latest
    echo "$response" | jq -r --arg prefix "$version_prefix" '
        [.imageTagDetails[] 
        | select(.imageTag | startswith($prefix + "."))
        | select(.imageTag | test("minimal|arm|amd") | not)
        | .imageTag]
        | sort_by(split(".") | map(tonumber? // .))
        | last
    '
}

# Function to extract version info from linux.version file
get_version_info() {
    local major_version="$1"
    local field="$2"
    local json_file="linux.version"

    jq -r ".[] | select(.linux.\"major-version\" == \"$major_version\") | .linux.\"$field\"" "$json_file"
}

# Function to extract all version information for a major version
extract_version_data() {
    local major_version="$1"

    # Create associative array to store version data
    declare -A version_data
    version_data[version]=$(get_version_info "$major_version" "version")
    version_data[fluent_bit]=$(get_version_info "$major_version" "fluent-bit")
    version_data[cloudwatch_plugin]=$(get_version_info "$major_version" "cloudwatch-plugin")
    version_data[kinesis_plugin]=$(get_version_info "$major_version" "kinesis-plugin")
    version_data[firehose_plugin]=$(get_version_info "$major_version" "firehose-plugin")
    version_data[latest]=$(get_version_info "$major_version" "latest")

    # Return the data (we'll use the latest version for the changelog)
    if [[ "${version_data[latest]}" == "true" ]]; then
        echo "${version_data[version]} ${version_data[fluent_bit]} ${version_data[cloudwatch_plugin]} ${version_data[kinesis_plugin]} ${version_data[firehose_plugin]}"
    fi
}

# Function to generate changelog section for a specific version
generate_version_section() {
    local major_version="$1"
    local al_tag="$2"
    local most_recent_al_version="$3"

    local version=$(get_version_info "$major_version" "version")
    local fluent_bit_version=$(get_version_info "$major_version" "fluent-bit")
    local cloudwatch_plugin_version=$(get_version_info "$major_version" "cloudwatch-plugin")
    local kinesis_plugin_version=$(get_version_info "$major_version" "kinesis-plugin")
    local firehose_plugin_version=$(get_version_info "$major_version" "firehose-plugin")
    local publish=$(get_version_info "$major_version" "publish")

    # Only generate section if this version should be published
    if [[ "$publish" == "true" ]]; then
        local al_name
        if [[ "$al_tag" == "2" ]]; then
            al_name="Amazon Linux 2"
        elif [[ "$al_tag" == "2023" ]]; then
            al_name="Amazon Linux 2023"
        else
            al_name="Amazon Linux $al_tag"
        fi

        if [[ "$al_tag" == "2023" ]]; then
            cat << EOF
### $version
This release includes:
* Fluent Bit [$fluent_bit_version](https://github.com/fluent/fluent-bit/tree/v${fluent_bit_version#v})
* Amazon CloudWatch Logs for Fluent Bit ${cloudwatch_plugin_version#v}
* Amazon Kinesis Streams for Fluent Bit ${kinesis_plugin_version#v}
* Amazon Kinesis Firehose for Fluent Bit ${firehose_plugin_version#v}
* Minimal set of packages installed using Amazon Linux 2023 container image version: $most_recent_al_version

Compared to the previous release, this release adds:
* Fix - TODO blah blah [#TODO](https://github.com/amazon-contributing/upstream-to-fluent-bit/pull/TODO)
* Enhancement - TODO blah blah [#TODO](https://github.com/aws/aws-for-fluent-bit/pull/TODO)

EOF
        else
            cat << EOF
### $version
This release includes:
* Fluent Bit [v$fluent_bit_version](https://github.com/fluent/fluent-bit/tree/v${fluent_bit_version#v})
* Amazon CloudWatch Logs for Fluent Bit ${cloudwatch_plugin_version#v}
* Amazon Kinesis Streams for Fluent Bit ${kinesis_plugin_version#v}
* Amazon Kinesis Firehose for Fluent Bit ${firehose_plugin_version#v}
* $al_name base container image version: $most_recent_al_version

Compared to the previous release, this release adds:
* Fix - TODO blah blah [#TODO](https://github.com/amazon-contributing/upstream-to-fluent-bit/pull/TODO)
* Enhancement - TODO blah blah [#TODO](https://github.com/aws/aws-for-fluent-bit/pull/TODO)

EOF
        fi
    fi
}

# Main function to orchestrate changelog generation
main() {
    # Get the most recent AL versions directly using version-based sorting
    local most_recent_al2=$(get_latest_al_version "2")
    local most_recent_al2023=$(get_latest_al_version "2023")

    # Get all major versions from linux.version file
    local major_versions=$(jq -r '.[].linux."major-version"' linux.version)

    # Generate changelog sections for each version
    for major_version in $major_versions; do
        local al_tag=$(get_version_info "$major_version" "al-tag")
        local most_recent_al_version

        # Get the appropriate most recent AL version based on al-tag
        if [[ "$al_tag" == "2" ]]; then
            most_recent_al_version="$most_recent_al2"
        elif [[ "$al_tag" == "2023" ]]; then
            most_recent_al_version="$most_recent_al2023"
        else
            # For future AL versions, try to get the most recent version
            most_recent_al_version=$(get_latest_al_version "$al_tag")
        fi

        generate_version_section "$major_version" "$al_tag" "$most_recent_al_version"
    done
}

# Execute main function
main "$@"
