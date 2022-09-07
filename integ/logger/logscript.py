import time
import sys

"""
This script writes 1000 log lines, then sleeps for 20 seconds, and then exits
"""

for i in range(0, 1000):
    print(i)

time.sleep(20)
sys.exit(0)
