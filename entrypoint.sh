tput setaf 5;
tput bold;
echo -n "AWS for Fluent Bit Container Image Version "
cat /AWS_FOR_FLUENT_BIT_VERSION
tput sgr0;

# Extra parsers configuration
cat >> /fluent-bit/etc/parsers.conf <<EOF

[PARSER]
  Name         python_log_date
  Format       regex
  Regex        /\d{4}-\d{1,2}-\d{1,2}/
  
[PARSER]
  Name        python_log_attrib
  Format      regex
  Regex       /(?<timestamp>[^ ]* [^ ]*) (?<level>[^\s]+:)(?<message>[\s\S]*)/

EOF

exec /fluent-bit/bin/fluent-bit -e /fluent-bit/firehose.so -e /fluent-bit/cloudwatch.so -e /fluent-bit/kinesis.so -c /fluent-bit/etc/fluent-bit.conf
