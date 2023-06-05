import sys

matches = []
for arg in sys.argv[2:]:
    matches.append(arg)

file = open(sys.argv[1], 'r')
lines = file.readlines()

for line in lines:
    if all(match in line for match in matches):
        print(line, end="")

