#!/bin/bash

# Run the init Go application first, that sets up the fluent bit configs and the invoke script as needed
./init/fluent_bit_init_process

# Source the invoke script from the appropriate location
if [ -f /init/invoke_fluent_bit.sh ]; then
    source /init/invoke_fluent_bit.sh
elif [ -f /tmp/init/invoke_fluent_bit.sh ]; then
    source /tmp/init/invoke_fluent_bit.sh
else
    echo "Error: invoke_fluent_bit.sh not found in /init or /tmp/init"
    exit 1
fi
