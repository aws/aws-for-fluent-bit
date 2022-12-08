#!/usr/bin/env python3
import sys

# First argument would be the platform.
platform = sys.argv[1]

numeric_tags = []
for tag in sys.argv[2:]:
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
print(numeric_tags[0])
