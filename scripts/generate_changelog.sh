#!/bin/bash
set -xeuo pipefail

# Find the most recent AL2 tag
most_recent_al2=$(./scripts/most_recent_al2.sh)

# Read the JSON file
json_file="linux.version"
json_content=$(cat "$json_file")

# Extract values using jq
version=$(echo "$json_content" | jq -r '.linux.version')
fluent_bit_version=$(echo "$json_content" | jq -r '.linux."fluent-bit"')
cloudwatch_plugin_version=$(echo "$json_content" | jq -r '.linux."cloudwatch-plugin"')
kinesis_plugin_version=$(echo "$json_content" | jq -r '.linux."kinesis-plugin"')
firehose_plugin_version=$(echo "$json_content" | jq -r '.linux."firehose-plugin"')

changelog_commit=$(git log -n1 --pretty=format:%h CHANGELOG.md)
changelog_commit_date="$(git show --no-patch --format=%ci $changelog_commit)"
current_commit=$(git log -n1 --pretty=format:%h)

# Test Overrides


upstream_changes=false
newer_upstream_changes=""
if [ "${#FLUENT_BIT_DIRECTORY}" -ge 1 ]; then
    newer_upstream_changes=$(cd $FLUENT_BIT_DIRECTORY; git log --pretty=format:%s --after "$changelog_commit_date")
    # If there are NOT newer changes
    if [ ${#newer_upstream_changes} -le 1 ]; then
        FLUENT_BIT_DIRECTORY=""
    fi
fi

compared_string=""

add_changelog_changes=false
flb_has_changes=false
we_have_changes=false
if [ "${#FLUENT_BIT_DIRECTORY}" -ge 1 ]; then
    flb_has_changes=true
fi
if [ "$changelog_commit" != "$current_commit" ]; then
    we_have_changes=true
fi

if [ "$we_have_changes" = true ] || [ "$flb_has_changes" = true ]; then
    compared_string="
Compared to the previous release, this release adds:"
    commit_names=$(git log --pretty=format:%s "$changelog_commit".."$current_commit")
    if [ "$flb_has_changes" = true ]; then
        # Get commits from the upstream as well
        # Add newline to separate from existing commits
        commit_names+="
"
        # Add FLB commit names to the list considered for changelog updates
        commit_names+="$newer_upstream_changes"
    fi
    original_ifs=$IFS
    IFS="
"
    for line in $commit_names
    do
        IFS=" "
        found_label=false
        for word in $line
        do
            # Look for an indication of what this commit is about
            # unless we already are at the stage of collecting
            # the name
            if [ "$found_label" = false ]; then
                # Factor out setting this to true if a
                # label is found, reducing boilerplate
                found_label=true
                if [ "$word" = "feature:" ]; then
                    compared_string+="
* Feature - "
                    continue
                elif [ "$word" = "enhancement:" ]; then
                    compared_string+="
* Enhancement - "
                    continue
                elif [ "$word" = "fix:" ] || [ "$word" = "bugfix:" ]; then
                    compared_string+="
* Fix - "
                    continue
                elif [ "$word" = "Fix" ]; then
                    compared_string+="
* Fix - "
                    # We don't continue for the enclosing elif,
                    # i.e. we add "Fix" as the first word
                elif [ $(echo "$word" | grep "\(aws:\|out_cloudwatch_logs:\|out_s3:\|out_kinesis:\|filter_ecs:\|filter_kubernetes:\)") ]; then
                    change_type="Enhancement"
                    for inner_word in $line
                    do
                        if [ $(echo "$inner_word" | grep '\(fix\|Fix\|bugfix\)') ]; then
                            change_type="Fix"
                            break
                        elif [ $(echo "$inner_word" | grep '\(add\|Add\)') ]; then
                            change_type="Feature"
                            break
                        elif [ $(echo "$inner_word" | grep '\(allow\|support\)') ]; then
                            # Enhancement is the default
                            break
                        fi
                    done

                    compared_string+="
* $change_type - "
                    continue
                else
                    # No label was found
                    found_label=false
                fi
            fi
            if [ "$found_label" = false ]; then
                # If no label, skip this commit
                break 1
            else
                # Add each word aside from the prefix to the commit changelog description
                compared_string+=$word
                compared_string+=" "
            fi
        done
        IFS="
"
    done
    # Append newline to separate from the next changelog entry
    compared_string+="
"
    IFS=$original_ifs
fi

# Generate the changelog entry

new_changelog="
### $version
This release includes:
* Fluent Bit [$fluent_bit_version](https://github.com/fluent/fluent-bit/tree/v$fluent_bit_version)
* Amazon CloudWatch Logs for Fluent Bit ${cloudwatch_plugin_version#v}
* Amazon Kinesis Streams for Fluent Bit ${kinesis_plugin_version#v}
* Amazon Kinesis Firehose for Fluent Bit ${firehose_plugin_version#v}
* Amazon Linux base container image version: $most_recent_al2
$compared_string"

heads=$(head -n 1 CHANGELOG.md)
tails=$(tail -n +3 CHANGELOG.md)

rm -f temp_changelog.txt
echo "$heads" >> temp_changelog.txt
echo "$new_changelog" >> temp_changelog.txt
echo "$tails" >> temp_changelog.txt

mv -f temp_changelog.txt CHANGELOG.md
rm -f temp_changelog.txt

