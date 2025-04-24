#!/bin/bash

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

echo $most_recent_al2
