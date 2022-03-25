#!/bin/bash

# Rebuild (on Change)
# For VSCode Fluent-Bit
# The following detects changes to the following
# watched directories and files, and will initiate a
# rebuild on modification.
watch='src/ plugins/'

# Kill old fluent-bit processes (might not be the best place for this)
kill -9 $(pgrep fluent-bit)

# OpenSSL Key Export
# export SSLKEYLOGFILE=/Users/falamatt/fluentbit-premaster
# export LD_PRELOAD=.vscode/Scripts/libsslkeylog.so
LD_PRELOAD=""

# Keep a record of the latest update
# prior to the last build
memoryFile="./.vscode/Scripts/.latestchange"
[ -f $memoryFile ] || touch $memoryFile
lts1=`cat $memoryFile`
if uname | grep -q "Darwin"; then
    lts2=`find $watch -type f -print0 | xargs -0 stat -f "%m %N" | sort -rn | head -1 | cut -f 1 -d " "`
else
    lts2=`find $watch -type f -print0 | xargs -0 stat -c %Y | sort -rn | head -1`
fi

if [[ $lts1 != $lts2 ]] ; then
    # Rebuild
    cd build
    cmake -DFLB_DEV=On ../
    make
    cd ..
    # Make could modify files, so save a fresh timestamp
    if uname | grep -q "Darwin"; then
        echo `find $watch -type f -print0 | xargs -0 stat -f "%m %N" | sort -rn | head -1 | cut -f 1 -d " "` > $memoryFile
    else
        echo `find $watch -type f -print0 | xargs -0 stat -c %Y | sort -rn | head -1 | cut -f 1 -d " "` > $memoryFile
    fi
fi
