#!/usr/bin/env python3
import sys

# first argument is the platform
platform = sys.argv[1]

# second argument is the version to check. 
# "latest" => prints latest version. 
# "version number" => prints is_not_latest && is_published
# this means it prints 'true' if and only if we should try to sync a non-latest version that was already published to DockerHub
check_version = sys.argv[2]


numeric_tags = []
for tag in sys.argv[3:]: # third argument starts the taglist
    if tag[0].isdigit():
        tag_to_store = tag
        if platform == 'linux':
            # This is the case wherein we encounter tags for Windows. For Linux, we skip the same.
            if tag.find("windowsservercore") != -1 or tag.find("ltsc") != -1:
                continue
        if platform == 'windows':
            # When we do not encounter Windows tag, we skip it.
            if tag.find("windowsservercore") == -1:
                continue
            # For Windows, we store the prefix version.
            tag_to_store = tag.split("-")[0]

        numeric_tags.append(tag_to_store)

numeric_tags.sort(key=lambda s: list(map(int, s.split('.'))), reverse=True)

if check_version == "latest":
    print(numeric_tags[0]) # print latest version number
else:
    # prints true if the version is in the list but not latest
    # printing true means publish.sh sync a non-latest version
    is_latest = (numeric_tags[0] == check_version)
    is_published = check_version in numeric_tags
    print(str(not is_latest and is_published).lower()) 
    # prints true if the version number passed as arg is not the latest and is published in DockerHub
    # which means we have a non-latest release to sync
