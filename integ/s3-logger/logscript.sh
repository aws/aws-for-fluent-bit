#!/bin/bash

# Writes 7717 unique log lines
# intermixed with 1 KB lines of random data
# these logs are written over the course of a little over 1 minute
# because we want to test S3's local buffering
# Why 7717? Its a prime number. And I like that.
# Finally we sleep for 90s- ensuring the upload timeout hits for the last chunk
# then exit

for i in {0..7716}
do
    echo $i
    openssl rand -base64 1000 | tr '\n' '-' && echo ""
    sleep 0.0001
done

sleep 90

exit 0
