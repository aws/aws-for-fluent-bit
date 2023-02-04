#!/bin/bash

# Writes 500 log lines per second

while :
do
    for i in {0..${LOGGER_RATE}}
    do
        openssl rand -base64 ${LOG_SIZE}
    done
    sleep 1
done