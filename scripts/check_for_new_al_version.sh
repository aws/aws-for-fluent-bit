#!/bin/bash

most_recent_al2=$(./scripts/most_recent_al2.sh)
last_used_al2=$(grep "Amazon Linux base container image version" CHANGELOG.md | head -n 1 | grep -o ': .*$' | cut -c 3-)

# Return true if there's a newer version than ours
if [ "$last_used_al2" != "$most_recent_al2" ]; then
    echo "true"
else
    echo "false"
fi
