#!/bin/bash
set -euo pipefail

# Function to fetch all Amazon Linux image data from Public ECR API
# Returns the full JSON response
fetch_all_al_images() {
    curl -sSL \
        --header "Content-Type: application/json" \
        --request POST \
        --data '{"registryAliasName":"amazonlinux","repositoryName":"amazonlinux","maxResults":1000}' \
        https://api.us-east-1.gallery.ecr.aws/describeImageTags
}

# Function to get the latest version and SHA256 for a specific AL version from cached response
# Returns: "version sha256" (space-separated)
get_latest_al_version_and_sha_from_response() {
    local response="$1"
    local version_prefix="$2"
    
    # Use jq to filter by prefix, exclude variants, sort by version, and get the latest with its SHA256
    echo "$response" | jq -r --arg prefix "$version_prefix" '
        [.imageTagDetails[] 
        | select(.imageTag | startswith($prefix + "."))
        | select(.imageTag | test("minimal|arm|amd") | not)
        | {tag: .imageTag, sha: .imageDetail.imageDigest}]
        | sort_by(.tag | split(".") | map(tonumber? // .))
        | last
        | "\(.tag) \(.sha | split(":")[1])"
    '
}

# Function to extract version info from linux.version file
get_version_info() {
    local major_version="$1"
    local field="$2"
    local json_file="linux.version"

    jq -r ".[] | select(.linux.\"major-version\" == \"$major_version\") | .linux.\"$field\"" "$json_file"
}

# Function to update os-digest in linux.version file
update_os_digest() {
    local al_tag="$1"
    local sha256="$2"
    local json_file="linux.version"

    # Create a temporary file
    local temp_file=$(mktemp)

    # Update the os-digest field for the matching al-tag
    jq --arg tag "$al_tag" --arg digest "sha256:$sha256" '
        map(
            if .linux."al-tag" == $tag then
                .linux."os-digest" = $digest
            else
                .
            end
        )
    ' "$json_file" > "$temp_file"

    # Replace the original file with the updated one
    mv "$temp_file" "$json_file"

    echo "Set os-digest for AL $al_tag to sha256:$sha256" >&2
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
        al_name="Amazon Linux $al_tag"

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
    # Get list of al-tags that have publish=true
    local publish_al_tags=$(jq -r '.[] | select(.linux.publish == "true") | .linux."al-tag"' linux.version)

    # Check if we have any versions to publish
    if [[ -n "$publish_al_tags" ]]; then
        echo "=== Latest Amazon Linux Image Information ===" >&2

        # Declare associative arrays to store version and SHA data
        declare -A al_versions
        declare -A al_shas

        # Fetch all AL image data once
        local al_images_response=$(fetch_all_al_images)

        # Process data for each AL version that is being published
        local count=0
        local total=$(echo "$publish_al_tags" | wc -w)
        
        for al_tag in $publish_al_tags; do
            count=$((count + 1))
            local al_data=$(get_latest_al_version_and_sha_from_response "$al_images_response" "$al_tag")
            al_versions[$al_tag]=$(echo "$al_data" | cut -d' ' -f1)
            al_shas[$al_tag]=$(echo "$al_data" | cut -d' ' -f2)

            # Print the information
            echo "Amazon Linux $al_tag: ${al_versions[$al_tag]}" >&2
            echo "  SHA256: ${al_shas[$al_tag]}" >&2
            echo "" >&2

            # Update os-digest in linux.version file
            update_os_digest "$al_tag" "${al_shas[$al_tag]}"
            
            # Add spacing after os-digest update (except for the last one)
            if [[ $count -lt $total ]]; then
                echo "" >&2
            fi
        done

        echo "=============================================" >&2
        echo "" >&2
    fi

    # Get all major versions from linux.version file
    local major_versions=$(jq -r '.[].linux."major-version"' linux.version)

    # Generate changelog sections for each version
    for major_version in $major_versions; do
        local al_tag=$(get_version_info "$major_version" "al-tag")
        local most_recent_al_version=""

        # Get the AL version if it was fetched (i.e., if this version is being published)
        if [[ -n "${al_versions[$al_tag]:-}" ]]; then
            most_recent_al_version="${al_versions[$al_tag]}"
        fi

        generate_version_section "$major_version" "$al_tag" "$most_recent_al_version"
    done
}

# Execute main function
main "$@"
