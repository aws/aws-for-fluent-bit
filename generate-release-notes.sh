#!/bin/bash

set -eo pipefail

MAJOR_VERSION=""
VERSION_FILE="linux.version"
METADATA_KEYS=("fluent-bit" "kinesis-plugin" "firehose-plugin" "cloudwatch-plugin")

usage() {
	cat <<-EOF
		Usage:
		  $0

		Options:
			--major-version  (Required) Major version of AWS Fluentbit that we're generating release notes for (e.g. 2 or 3)

		Example:
		  $0 --major-version 3
	EOF
}

parse_args() {
	while :; do
		case $1 in
		--major-version)
			MAJOR_VERSION="$2"
			shift
			;;
		*)
			break
			;;
		esac
		shift
	done
}

validate_args() {
	if [[ -z "$MAJOR_VERSION" ]]; then
		usage
		exit 1
	fi
}

generate_release_notes() {
	local index=$1
	local version=$(jq -r ".[$index].linux.\"version\"" "$VERSION_FILE")
	if [[ -z "$version" ]]; then
		echo "Error: version JSON field either could not be found or value is empty in $VERSION_FILE"
		exit 1
	fi

	sanitized_version=$(echo "$version" | tr -d '.')
	release_notes="### Source Image release notes
---
* [Amazon Linux 2023 release notes](https://docs.aws.amazon.com/linux/al2023/release-notes/relnotes.html)
* [Amazon Linux 2 release notes](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-al2.html)

### Changelog
---
https://github.com/aws/aws-for-fluent-bit/blob/mainline/CHANGELOG.md#${sanitized_version}

### AWS Fluent Bit image $version
---"

	for key in "${METADATA_KEYS[@]}"; do
		value=$(jq -r ".[$index].linux.\"$key\"" "$VERSION_FILE")
		if [[ -z "$value" ]]; then
			echo "Error: $key JSON field either could not be found or value is empty in $VERSION_FILE"
			exit 1
		fi
		release_notes="${release_notes}
* $key: $value"
	done

	printf "$release_notes\n"
}

main() {
	parse_args "$@"
	validate_args

	index=-1
	for i in $(jq 'keys[]' "$VERSION_FILE"); do
		major_version=$(jq -r ".[$i].linux.\"major-version\"" "$VERSION_FILE")
		if [[ $MAJOR_VERSION == $major_version ]]; then
			index=$i
		fi
	done

	if [[ "$index" -lt "0" ]]; then
		echo "Error: Cannot find major version $MAJOR_VERSION in $VERSION_FILE."
		exit 1
	fi

	generate_release_notes "$index"
}

main "$@"
