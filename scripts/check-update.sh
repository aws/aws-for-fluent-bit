#!/usr/bin/env bash
set -euo pipefail

readonly VERSION_FILE="linux.version"
readonly ECR_REPO="public.ecr.aws/amazonlinux/amazonlinux"
readonly STABLE_VERSION_FILE="AWS_FOR_FLUENT_BIT_STABLE_VERSION"

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
	jq ".[$key].linux.\"$field\" = \"$value\"" "$VERSION_FILE" >tmp.json && mv tmp.json "$VERSION_FILE"
}

# Compute the next AWS for Fluent Bit version based on the type of change.
#
# Versioning rules (from the release runbook):
#   MAJOR.MINOR.PATCH       — used by 3.x (AL2023)
#   MAJOR.MINOR.PATCH.BUILD — used by 2.x (AL2)
#
# - Base-image-only change (os_updated, no fluentbit bump):
#     2.x → bump BUILD to today's date (YYYYMMDD)
#     3.x → bump PATCH
# - Fluent Bit minor version bump (e.g., 4.2.x → 4.3.x):
#     Both → bump MINOR, reset PATCH to 0
# - Fluent Bit patch version bump (e.g., 4.2.2 → 4.2.3):
#     Both → bump PATCH
compute_new_version() {
	local current_version="$1"
	local major_version="$2"
	local os_updated="$3"
	local fluentbit_updated="$4"
	local old_fluentbit="${5:-}"
	local new_fluentbit="${6:-}"

	# Parse current version components
	local major minor patch build
	IFS='.' read -r major minor patch build <<<"$current_version"

	if [[ "$fluentbit_updated" == "true" ]]; then
		# Determine whether the Fluent Bit change is a minor or patch bump
		# by comparing the minor component of the old and new Fluent Bit versions.
		local old_fb_minor new_fb_minor
		old_fb_minor=$(echo "${old_fluentbit#v}" | cut -d. -f2)
		new_fb_minor=$(echo "${new_fluentbit#v}" | cut -d. -f2)

		if [[ "$new_fb_minor" != "$old_fb_minor" ]]; then
			# Fluent Bit minor bump → AWS FB minor bump
			minor=$((minor + 1))
			patch=0
		else
			# Fluent Bit patch bump → AWS FB patch bump
			patch=$((patch + 1))
		fi
		echo "${major}.${minor}.${patch}"
	elif [[ "$os_updated" == "true" ]]; then
		if [[ "$major_version" == "2" ]]; then
			# 2.x base-image-only → set BUILD to today's date (YYYYMMDD)
			local today
			today=$(date '+%Y%m%d')
			echo "${major}.${minor}.${patch}.${today}"
		else
			# 3.x base-image-only → bump PATCH
			patch=$((patch + 1))
			echo "${major}.${minor}.${patch}"
		fi
	else
		# No change — return current version unchanged
		echo "$current_version"
	fi
}

# Function that checks and updates the release config file for any of the following:
# - New Amazon Linux docker image (tracked by image SHA)
# - New upstream Fluentbit version to be consumed
# - New AWS Fluentbit version to be released (auto-computed from the above)
check_and_update() {
	local any_version_updated="false"

	for i in $(jq 'keys[]' "$VERSION_FILE"); do
		local os_updated="false"
		local fluentbit_updated="false"

		current_sha=$(jq -r ".[$i].linux.\"os-digest\"" "$VERSION_FILE")
		tag=$(jq -r ".[$i].linux.\"al-tag\"" "$VERSION_FILE")
		major_version=$(jq -r ".[$i].linux.\"major-version\"" "$VERSION_FILE")
		latest=$(jq -r ".[$i].linux.\"latest\"" "$VERSION_FILE")

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
			os_updated="true"
		fi

		curr_fluentbit_version=$(jq -r ".[$i].linux.\"fluent-bit\"" "$VERSION_FILE")
		release_fluentbit_version=$(jq -r ".[$i].linux.\"release-fluent-bit\"" "$VERSION_FILE")
		if [[ "$curr_fluentbit_version" != "$release_fluentbit_version" ]]; then
			echo "Upgrading to new Fluentbit version."
			update_json_field "$i" "fluent-bit" "$release_fluentbit_version"
			fluentbit_updated="true"
		fi

		# Determine the new AWS for Fluent Bit version.
		# A manually set release-version (differs from version) takes priority
		# over auto-computation from upstream changes.
		curr_aws_fb_version=$(jq -r ".[$i].linux.\"version\"" "$VERSION_FILE")
		release_aws_fb_version=$(jq -r ".[$i].linux.\"release-version\"" "$VERSION_FILE")

		if [[ "$curr_aws_fb_version" != "$release_aws_fb_version" ]]; then
			# Manual release: someone updated release-version directly
			echo "Manual version override detected: $curr_aws_fb_version -> $release_aws_fb_version"
			update_json_field "$i" "version" "$release_aws_fb_version"
			update_json_field "$i" "publish" "true"
			any_version_updated="true"

			# Update the stable version to the new version if latest has been updated
			if [[ "$latest" = "true" ]]; then
				echo "Updating stable version to $release_aws_fb_version"
				echo "$release_aws_fb_version" >"$STABLE_VERSION_FILE"
			fi

		elif [[ "$os_updated" == "true" || "$fluentbit_updated" == "true" ]]; then
			# Auto-compute version from upstream changes
			new_aws_fb_version=$(compute_new_version "$curr_aws_fb_version" "$major_version" "$os_updated" "$fluentbit_updated" "$curr_fluentbit_version" "$release_fluentbit_version")
			echo "Bumping AWS for Fluent Bit version: $curr_aws_fb_version -> $new_aws_fb_version"
			update_json_field "$i" "version" "$new_aws_fb_version"
			update_json_field "$i" "release-version" "$new_aws_fb_version"
			update_json_field "$i" "publish" "true"
			any_version_updated="true"

			# Update the stable version to the new version if latest has been updated
			if [[ "$latest" = "true" ]]; then
				echo "Updating stable version to $new_aws_fb_version"
				echo "$new_aws_fb_version" >"$STABLE_VERSION_FILE"
			fi
		else
			update_json_field "$i" "publish" "false"
		fi
	done

	# Only stage changes if at least one version was updated
	if [[ "$any_version_updated" = "true" ]]; then
		git add "$VERSION_FILE" "$STABLE_VERSION_FILE"

		# Generate and prepend new changelog entries
		SCRIPTS_DIR="$(dirname "${BASH_SOURCE[0]}")"
		"${SCRIPTS_DIR}/generate_changelog.sh"

		git status
	fi
}

main() {
	check_and_update
}

trap cleanup EXIT

main "$@"
