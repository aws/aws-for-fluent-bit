echo -n "AWS for Fluent Bit Container Image Version "
cat /AWS_FOR_FLUENT_BIT_VERSION

FLUENT_BIT_CONFIG_FILE=${FLUENT_BIT_CONFIG_FILE:-'/fluent-bit/etc/fluent-bit.conf'}

exec /fluent-bit/bin/fluent-bit -e /fluent-bit/firehose.so -e /fluent-bit/cloudwatch.so -e /fluent-bit/kinesis.so -c ${FLUENT_BIT_CONFIG_FILE}
