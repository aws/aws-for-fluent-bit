#!/usr/bin/env bash

# Write a single EMF payload to the TCP socket
# https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Embedded_Metric_Format_Specification.html

metricNamespace="fluent-metrics"
metricName="fluent-bit-integ-test-$(echo $RANDOM)"
metricValue=100

# pass the metric-name to a file in the shared volume for validation
echo $metricName > $EMF_METRIC_NAME_PATH

emfPayload='{"_aws":{"Timestamp":'"$(date +%s)000"',"CloudWatchMetrics":[{"Namespace":"'"$metricNamespace"'","Dimensions":[["dimensionKey"]],"Metrics":[{"Name":"'"$metricName"'"}]}]},"dimensionKey":"dimensionValue","'"$metricName"'":'"$metricValue"'}'
echo $emfPayload > /dev/tcp/fluent-bit/5170

sleep 120

exit 0
