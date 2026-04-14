#!/usr/bin/env bash
set -euo pipefail

readonly VERSION_FILE="linux.version"
readonly CHANGELOG_FILE="CHANGELOG.md"
readonly REPO="aws/aws-for-fluent-bit"

WORK_DIR="$(mktemp -d)"
trap "rm -rf ${WORK_DIR}" EXIT

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

	jq -r ".[] | select(.linux.\"major-version\" == \"$major_version\") | .linux.\"$field\"" "$VERSION_FILE"
}

# Get PR titles merged since the last "Release XXXX" commit via the GitHub CLI (gh) to query merged PRs by date
get_changes_since_last_release() {
	local last_release_merged_at
	last_release_merged_at=$(gh pr list \
		--repo "$REPO" \
		--state merged \
		--base mainline \
		--search "head:release- sort:updated-desc" \
		--limit 1 \
		--json mergedAt \
		--jq '.[0].mergedAt' 2>/dev/null || true)

	if [ -z "$last_release_merged_at" ] || [ "$last_release_merged_at" = "null" ]; then
		echo "WARNING: Could not find last release PR merge timestamp" >&2
		return
	fi

	echo "Fetching merged PRs since last release PR (merged at ${last_release_merged_at})..." >&2

	# Use GitHub CLI if available to get merged PR titles
	local pr_titles
	pr_titles=$(gh pr list \
		--repo "$REPO" \
		--base mainline \
		--state merged \
		--search "merged:>=${last_release_merged_at}" \
		--json title,number,mergedAt \
		--jq '.[] | select(.title | test("^(stable:|Release \\d)"; "i") | not) | "* \(.title) [#\(.number)](https://github.com/'"$REPO"'/pull/\(.number))"' \
		2>/dev/null || true)

	if [[ -n "$pr_titles" ]]; then
		echo "$pr_titles"
		return
	fi
}

# Generate a single changelog entry for a major version and append to an entry file
generate_entry() {
	local major_version="$1"
	local al_version="$2"
	local commits="$3"
	local entry_file="$4"

	local version al_tag
	version=$(get_version_info "$major_version" "version")
	al_tag=$(get_version_info "$major_version" "al-tag")

	cat >>"$entry_file" <<EOF
### $version
* Minimal set of packages installed using Amazon Linux $al_tag container image version: $al_version
EOF
	if [[ -n "$commits" ]]; then
		echo "$commits" >>"$entry_file"
	fi
	echo "" >>"$entry_file"
}

prepend_to_changelog() {
	local entry_file="$1"

	local first_release_line
	first_release_line=$(grep -n '^### [0-9]' "$CHANGELOG_FILE" | head -1 | cut -d: -f1)

	if [ -z "$first_release_line" ]; then
		echo "ERROR: Could not find any release entry in CHANGELOG.md" >&2
		exit 1
	fi

	# Build new changelog: header + new entry + blank line + existing entries
	local tmpfile
	tmpfile=$(mktemp)
	head -n $((first_release_line - 1)) "$CHANGELOG_FILE" >"$tmpfile"
	cat "$entry_file" >>"$tmpfile"
	tail -n +${first_release_line} "$CHANGELOG_FILE" >>"$tmpfile"
	mv "$tmpfile" "$CHANGELOG_FILE"
}

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

	# Get merged PR titles since the last release (shared across all entries)
	local commits
	commits=$(get_changes_since_last_release)
	echo "Changes since last release:" >&2
	echo "$commits" >&2

	# Generate a temporary file to hold new changelog entries
	local entry_file=$(mktemp -p "$WORK_DIR")

	# Declare associative arrays to store version and SHA data
	declare -A al_versions
	declare -A al_shas

	for major_version in $publish_versions; do
		local al_tag
		al_tag=$(get_version_info "$major_version" "al-tag")

		local al_data
		al_data=$(get_latest_al_version_and_sha_from_response "$al_images_response" "$al_tag")

		al_versions[$al_tag]=$(echo "$al_data" | cut -d' ' -f1)
		al_shas[$al_tag]=$(echo "$al_data" | cut -d' ' -f2)

		# Print the Amazon linux image information
		printf "Amazon Linux %s: %s\n\tSHA256: %s\n" "$al_tag" "${al_versions[$al_tag]}" "${al_shas[$al_tag]}" >&2

		local most_recent_al_version=""
		# Get the AL version if it was fetched (i.e., if this version is being published)
		if [[ -n "${al_versions[$al_tag]:-}" ]]; then
			most_recent_al_version="${al_versions[$al_tag]}"
		fi

		echo "Generating changelog entry for major version $major_version (AL $al_tag: $most_recent_al_version)" >&2
		generate_entry "$major_version" "$most_recent_al_version" "$commits" "$entry_file"
	done

	echo "New changelog entries generated:"
	cat "$entry_file"
	prepend_to_changelog "$entry_file"
	git add "$CHANGELOG_FILE"
}

main "$@"
