import time
import sys
import os
import random
import socket

"""
This script writes a single EMF payload to the TCP socket
https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Embedded_Metric_Format_Specification.html
"""

# Define constants
metricNamespace = "fluent-metrics"
metricName = 'fluent-bit-integ-test-{:d}'.format(random.randint(0, 32767))
metricValue = 100

# pass the metric-name to a file in the shared volume for validation
metricPath = os.getenv('EMF_METRIC_NAME_PATH')
file = open(metricPath, "w")
file.write(metricName)
file.close()

# EMF payload.
emfPayload = ('{{"_aws":{{"Timestamp":{:d}000,"CloudWatchMetrics":[{{"Namespace":"{:s}","Dimensions":[["dimensionKey"]]'
              ',"Metrics":[{{"Name":"{:s}"}}]}}]}},"dimensionKey":"dimensionValue","{:s}":{:d}}}\n').format(
    int(time.time()), metricNamespace, metricName, metricName, metricValue)

dataToSend = str.encode(emfPayload)

host = os.getenv('FLUENT_CONTAINER_IP')
if not host:
    # Fluent-bit container can also be resolved using the service name.
    # If the IP is not explicitly set then try to resolve it using the service name.
    host = "fluent-bit"
port = 5170

# Connect to the socket and write the EMF payload.
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.connect((host, port))
    s.send(dataToSend)
    s.close()

time.sleep(120)
sys.exit(0)
