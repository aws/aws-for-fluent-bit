#!/usr/bin/env bash
set -euo pipefail

readonly VERSION_FILE="linux.version"
readonly ECR_REPO="public.ecr.aws/amazonlinux/amazonlinux"

# List of docker tags that we want to clean up after
tags_to_cleanup=()

# Cleanup function that removes the pulled AL docker images
cleanup() {
    for i in "${tags_to_cleanup[@]}"; do
        docker rmi "${ECR_REPO}:$i" || true
    done
}

# Helper function to update the specific JSON key/field within the release config file
update_json_field() {
    local key="$1" field="$2" value="$3"
    jq ".[$key].linux.\"$field\" = \"$value\"" "$VERSION_FILE" > tmp.json && mv tmp.json "$VERSION_FILE"
}

# Function that checks and updates the release config file for any of the following:
# - New Amazon Linux docker image (tracked by image SHA)
# - New upstream Fluentbit version to consumed
# - New AWS Fluentbit version to be released (Updated to pull in any other updates/changes.)
check_and_update() {
    local any_version_updated="false"
    
    for i in $(jq 'keys[]' "$VERSION_FILE"); do
        local version_updated="false"
        
        current_sha=$(jq -r ".[$i].linux.\"os-digest\"" "$VERSION_FILE")
        tag=$(jq -r ".[$i].linux.\"al-tag\"" "$VERSION_FILE")

        if ! docker pull "${ECR_REPO}:$tag"; then
            echo "Warning: Failed to pull ${ECR_REPO}:$tag" >&2
            continue
        fi
        
        tags_to_cleanup+=("$tag")
        new_al_sha=$(docker inspect --format='{{index .RepoDigests 0}}' "${ECR_REPO}:$tag")
        # Extract just the SHA256 digest from the full repo digest
        new_sha_digest=$(echo "$new_al_sha" | sed 's/.*@//')
        
        if [[ "$new_sha_digest" != "$current_sha" ]]; then
            echo "New base amazon linux image for $tag. Updating..."
            update_json_field "$i" "os-digest" "$new_sha_digest"
            version_updated="true"
        fi

        curr_fluentbit_version=$(jq -r ".[$i].linux.\"fluent-bit\"" "$VERSION_FILE")
        release_fluentbit_version=$(jq -r ".[$i].linux.\"release-fluent-bit\"" "$VERSION_FILE")
        if [[ "$curr_fluentbit_version" != "$release_fluentbit_version" ]]; then
            echo "Upgrading to new Fluentbit version."
            update_json_field "$i" "fluent-bit" "$release_fluentbit_version"
            version_updated="true"
        fi

        curr_aws_fb_version=$(jq -r ".[$i].linux.\"version\"" "$VERSION_FILE")
        release_aws_fb_version=$(jq -r ".[$i].linux.\"release-version\"" "$VERSION_FILE")
        if [[ "$curr_aws_fb_version" != "$release_aws_fb_version" ]]; then
            echo "Upgrading to new AWS Fluentbit version."
            update_json_field "$i" "version" "$release_aws_fb_version"
            version_updated="true"
        fi

        # Set publish flag based on whether this version had updates
        if [[ "$version_updated" = "true" ]]; then
            update_json_field "$i" "publish" "true"
            any_version_updated="true"
        else
            update_json_field "$i" "publish" "false"
        fi
    done

    # Only stage changes if at least one version was updated
    if [[ "$any_version_updated" = "true" ]]; then
        git add "$VERSION_FILE"
        git status
    fi
}

main() {
    check_and_update
}

trap cleanup EXIT

main "$@"
