import sys

# the final utilized version of the validator can output histograms
# with a full list of all IDs lost
# the output missed a newline in the version used
# though which makes it hard to read/parse
# so this just fixes the output files

file = open(sys.argv[1], 'r')
lines = file.readlines()

# string that only occurs in all summary lines
TEST_SUMMARY_MARKER = 'total_input_record'

for line in lines:
    if TEST_SUMMARY_MARKER in line:
        # get summary
        index = line.find('last_lost=')
        if index == -1:
            print(line, end="")
        else:
            index = line.find(':', index)
            end = index - 1
            summary = line[:end]
            print(summary)
            print(line[end:], end="")
    else:
        print(line, end="")

