# Usage: Set the following env vars:
#
# STDOUT_LOGGER_RATE => logs per second to send to stdout
# FILE1_LOGGER_RATE => logs per second to send to /tail/file1.log$(date "+%Y-%m-%d-%H-%M-%S")
# TCP_LOGGER_RATE => logs per second to send to TCP_LOGGER_PORT
# TCP_LOGGER_PORT => TCP port of TCP input in Fluent Bit, if used
#
# If you do not need one of these loggers, simply remove its entry from the loop
#
# you can easily configure additional loggers as needed
# just add another entry in the while loop
# and import the new file in the Dockerfile


while true
do
    for i in {1..$TCP_LOGGER_RATE}
    do
        cat /tcp.log | nc 127.0.0.1 $TCP_LOGGER_PORT
    done
    for i in {1..$STDOUT_LOGGER_RATE}
    do
        cat /stdout.log
    done
    for i in {1..$FILE1_LOGGER_RATE}
    do
        # this sets up automatic rotation of the active file based on the date
        # automatic log file clean up is not currently in this image
        cat /file1.log >>  /tail/file1.log$(date "+%Y-%m-%d-%H")
    done
    sleep 1
done