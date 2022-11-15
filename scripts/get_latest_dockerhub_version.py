#!/usr/bin/env python3
import sys

numeric_tags = []
for tag in sys.argv:
    # Windows images have numeric starting but have letters separated by -.
    if tag[0].isdigit() and tag.find("-") == -1:
        numeric_tags.append(tag)

numeric_tags.sort(key=lambda s: list(map(int, s.split('.'))), reverse=True)
print(numeric_tags[0])
