#!/usr/bin/env bash
set -euo pipefail

# Generates changelog entries for versions with publish=true in linux.version
# and prepends them to CHANGELOG.md.
#
# Fetches the latest Amazon Linux image version from the Public ECR API
# to include in the changelog entry.

readonly VERSION_FILE="linux.version"
readonly CHANGELOG_FILE="CHANGELOG.md"

WORK_DIR="$(mktemp -d)"
trap "rm -rf ${WORK_DIR}" EXIT

# Fetch all Amazon Linux image data from Public ECR API
fetch_all_al_images() {
    curl -sSL \
        --header "Content-Type: application/json" \
        --request POST \
        --data '{"registryAliasName":"amazonlinux","repositoryName":"amazonlinux","maxResults":1000}' \
        https://api.us-east-1.gallery.ecr.aws/describeImageTags
}

# Get the latest version string for a specific AL tag (e.g., "2" or "2023")
# from the cached ECR API response.
get_latest_al_version() {
    local response="$1"
    local version_prefix="$2"

    echo "$response" | jq -r --arg prefix "$version_prefix" '
        [.imageTagDetails[]
        | select(.imageTag | startswith($prefix + "."))
        | select(.imageTag | test("minimal|arm|amd") | not)]
        | sort_by(.imageTag | split(".") | map(tonumber? // .))
        | last
        | .imageTag
    '
}

# Read a field from linux.version for a given major-version
get_version_info() {
    local major_version="$1"
    local field="$2"
    jq -r ".[] | select(.linux.\"major-version\" == \"$major_version\") | .linux.\"$field\"" "$VERSION_FILE"
}

# Generate a single changelog entry for a major version
generate_entry() {
    local major_version="$1"
    local al_version="$2"

    local version fluent_bit cw_plugin kinesis_plugin firehose_plugin al_tag
    version=$(get_version_info "$major_version" "version")
    fluent_bit=$(get_version_info "$major_version" "fluent-bit")
    cw_plugin=$(get_version_info "$major_version" "cloudwatch-plugin")
    kinesis_plugin=$(get_version_info "$major_version" "kinesis-plugin")
    firehose_plugin=$(get_version_info "$major_version" "firehose-plugin")
    al_tag=$(get_version_info "$major_version" "al-tag")

    local al_description
    if [[ "$al_tag" == "2023" ]]; then
        al_description="Minimal set of packages installed using Amazon Linux 2023 container image version: $al_version"
    else
        al_description="Amazon Linux $al_tag base container image version: $al_version"
    fi

    cat <<EOF
### $version
This release includes:
* Fluent Bit [v${fluent_bit#v}](https://github.com/fluent/fluent-bit/tree/v${fluent_bit#v})
* Amazon CloudWatch Logs for Fluent Bit ${cw_plugin#v}
* Amazon Kinesis Streams for Fluent Bit ${kinesis_plugin#v}
* Amazon Kinesis Firehose for Fluent Bit ${firehose_plugin#v}
* $al_description

Compared to the previous release, this release adds:
* Fix - TODO blah blah [#TODO](https://github.com/amazon-contributing/upstream-to-fluent-bit/pull/TODO)
* Enhancement - TODO blah blah [#TODO](https://github.com/aws/aws-for-fluent-bit/pull/TODO)

EOF
}

# { head -1 "$CHANGELOG_FILE"; echo ""; printf '%s' "$new_entries"; tail -n +2 "$CHANGELOG_FILE"; } > tmp && mv tmp "$CHANGELOG_FILE"

main() {
    # Collect major versions that have publish=true
    local publish_versions
    publish_versions=$(jq -r '.[] | select(.linux.publish == "true") | .linux."major-version"' "$VERSION_FILE")

    if [[ -z "$publish_versions" ]]; then
        echo "No versions to publish. Skipping changelog generation." >&2
        return 0
    fi

    echo "Fetching Amazon Linux image data for changelog..." >&2
    local al_images_response
    al_images_response=$(fetch_all_al_images)

    # Build all new entries into a single string
    local new_entries=""
    for major_version in $publish_versions; do
        local al_tag
        al_tag=$(get_version_info "$major_version" "al-tag")
        local al_version
        al_version=$(get_latest_al_version "$al_images_response" "$al_tag")

        echo "Generating changelog entry for major version $major_version (AL $al_tag: $al_version)" >&2
        new_entries+=$(generate_entry "$major_version" "$al_version")
        new_entries+=$'\n'
    done

    # Prepend new entries after the "# Changelog" header
    if [[ -f "$CHANGELOG_FILE" ]]; then
        local tmp
        tmp=$(mktemp)
        # Write header, new entries, then the rest of the file (skip the header line)
        echo "# Changelog" > "$tmp"
        echo "" >> "$tmp"
        printf '%s' "$new_entries" >> "$tmp"
        # Append everything after the first line (the existing "# Changelog" header)
        tail -n +2 "$CHANGELOG_FILE" >> "$tmp"
        mv "$tmp" "$CHANGELOG_FILE"
    else
        echo "# Changelog" > "$CHANGELOG_FILE"
        echo "" >> "$CHANGELOG_FILE"
        printf '%s' "$new_entries" >> "$CHANGELOG_FILE"
    fi

    echo "Changelog updated." >&2
    git add "$CHANGELOG_FILE"
}

main "$@"
