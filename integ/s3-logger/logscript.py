from base64 import b64encode
from os import urandom
import time
import sys

"""
This script writes 7717 unique log lines intermixed with 1 KB lines of random data.
These logs are written over the course of a little under 90 seconds because we want to test S3's local buffering.
Why 7717? Its a prime number. And I like that.
Finally we sleep for 90s- ensuring the upload timeout hits for the last chunk then exit.
"""

for i in range(0, 7717):
    print(i)
    random_bytes = urandom(1000)
    token = b64encode(random_bytes).decode('utf-8')
    print(token)
    time.sleep(0.01)

time.sleep(200)
sys.exit(0)