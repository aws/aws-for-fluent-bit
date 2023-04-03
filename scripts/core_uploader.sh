# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
# 	http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.


# This script uploads the following to the provided S3 bucket under S3_KEY_PREFIX
#   <s3_key>_<date>_HOSTNAME_RANDOM.core.zip
#   <s3_key>_<date>_HOSTNAME_RANDOM.executable
#   <s3_key>_<date>_HOSTNAME_RANDOM.stacktrace
#   <s3_key>_<date>_HOSTNAME_RANDOM.all.zip

export S3_BUCKET=$1
export S3_KEY_PREFIX=$2
export RUN_ID=$3
export CRASH_FOLDER="/cores-out" # Add all crash files to a cores-out folder for staging,
                                 # then copy over to the mounted volume /cores

# Folder Structure
# $CRASH_FOLDER: All the crash symbol information is combined and added to this folder.
#    It is uploaded to s3 and added to the /cores folder
# /cores: Files are sent to the cores folder

# Process crash symbols
export CORE_FILENAME=`basename $S3_KEY_PREFIX`_`date +"%FT%H%M%S"`${HOSTNAME+_host-$HOSTNAME}_${RUN_ID}

# Check if there is a corefile
export NO_CORE_STR="ls: cannot access $CRASH_FOLDER/core*: No such file or directory"
export LS_CORE_STR="$(ls $CRASH_FOLDER/core* 2>&1 >/dev/null)"

if [ "$NO_CORE_STR" == "$LS_CORE_STR" ]; then

    # No corefile
    echo "No core file to upload"
else
    # Zip and upload the core file first incase the other processes fail
    mv `ls $CRASH_FOLDER/core*` ${CORE_FILENAME}.core
    zip $CRASH_FOLDER/${CORE_FILENAME}.core.zip $CRASH_FOLDER/${CORE_FILENAME}.core

    # $CRASH_FOLDER
    #   - CORE_FILENAME.core.zip
    #   - CORE_FILENAME.core

    # Upload core zip
    aws s3 cp $CRASH_FOLDER/${CORE_FILENAME}.core.zip s3://${S3_BUCKET}/${S3_KEY_PREFIX}/

    # Remove corefile zip to root folder
    mv $CRASH_FOLDER/${CORE_FILENAME}.core.zip /tmp/${CORE_FILENAME}.core.zip

    # $CRASH_FOLDER
    #   - CORE_FILENAME.core

    # Process corefile, get stack trace and fluent bit executable. Add to zip.
    cp /fluent-bit/bin/fluent-bit ./${CORE_FILENAME}.executable
    gdb -batch -ex 'thread apply all bt full' -ex 'quit' '/fluent-bit/bin/fluent-bit' ${CORE_FILENAME}.core > $CRASH_FOLDER/${CORE_FILENAME}.stacktrace

    # $CRASH_FOLDER
    #   - CORE_FILENAME.core
    #   - CORE_FILENAME.executable
    #   - CORE_FILENAME.stacktrace

    # Zip the crashfiles
    zip -r $CRASH_FOLDER/${CORE_FILENAME}.all.zip $CRASH_FOLDER
    rm $CRASH_FOLDER/${CORE_FILENAME}.core
    mv /tmp/${CORE_FILENAME}.core.zip $CRASH_FOLDER/${CORE_FILENAME}.core.zip

    # $CRASH_FOLDER
    #   - CORE_FILENAME.core.zip
    #   - CORE_FILENAME.executable
    #   - CORE_FILENAME.stacktrace
    #   - CORE_FILENAME.all.zip

    # Send crash files to the /cores/ folder
    cp $CRASH_FOLDER/* /cores/

    # Send crash files to S3
    aws s3 cp $CRASH_FOLDER s3://${S3_BUCKET}/${S3_KEY_PREFIX}/ --recursive

    # Log stacktrace
    echo "Stacktrace - ${CORE_FILENAME}.stacktrace:"
    cat /cores/${CORE_FILENAME}.stacktrace

    # Delay for 1 minute to allow for slow EFS uploads to complete if used
    echo "Waiting 1 minute for EFS core file transfers to complete"
    sleep 60
fi
