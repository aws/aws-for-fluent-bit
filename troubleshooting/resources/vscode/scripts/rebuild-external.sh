#!/bin/bash

# Rebuild External Plugins (on Change)
# For VSCode Fluent-Bit
# The following detects changes to the following
# watched directories and files, and will initiate a
# rebuild on modification.
watch='*' # Watch all changes in the external plugin folder

cd "./.vscode/external-plugins"

for plugin in */; do
    # Step into plugin folder
    cd $plugin;

    # Keep a record of the latest update
    # prior to the last build
    mkdir -p bin/
    memoryFile="./bin/.latestchange"
    [ -f $memoryFile ] || touch $memoryFile
    lts1=`cat $memoryFile`
    if uname | grep -q "Darwin"; then
        lts2=`find $watch -type f -print0 | xargs -0 stat -f "%m %N" | sort -rn | head -1 | cut -f 1 -d " "`
    else
        lts2=`find $watch -type f -print0 | xargs -0 stat -c %Y | sort -rn | head -1`
    fi
    if [[ $lts1 != $lts2 ]] ; then
        # Rebuild
        make
        # Make could modify files, so save a fresh timestamp
        if uname | grep -q "Darwin"; then
            echo `find $watch -type f -print0 | xargs -0 stat -f "%m %N" | sort -rn | head -1 | cut -f 1 -d " "` > $memoryFile
        else
            echo `find $watch -type f -print0 | xargs -0 stat -c %Y | sort -rn | head -1 | cut -f 1 -d " "` > $memoryFile
        fi
    fi
    
    # Step out of plugin folder
    cd ..
done

cd "../../"
