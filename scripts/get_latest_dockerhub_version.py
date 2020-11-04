#!/usr/bin/env python3
import sys

numeric_tags = []
for tag in sys.argv:
    if tag[0].isdigit():
        numeric_tags.append(tag)

numeric_tags.sort(key=lambda s: list(map(int, s.split('.'))), reverse=True)
print(numeric_tags[0])
