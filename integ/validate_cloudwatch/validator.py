import boto3
import json
import sys
import os
import time
from datetime import datetime, timedelta


client = boto3.client('logs', region_name=os.environ.get('AWS_REGION'))
metrics_client = boto3.client("cloudwatch", region_name=os.environ["AWS_REGION"])
start_time = datetime.utcnow() - timedelta(seconds=10)
end_time = datetime.utcnow()

LOG_GROUP_NAME = os.environ.get('LOG_GROUP_NAME')

def validate_test_case(test_name, log_group, log_stream, validator_func):
    print('RUNNING: ' + test_name)
    response = client.get_log_events(logGroupName=log_group, logStreamName=log_stream)
    # test length
    if len(response['events']) != 1000:
        print(str(len(response['events'])) + ' events found in CloudWatch')
        sys.exit('TEST_FAILURE: incorrect number of log events found')

    counter = 0
    for log in response['events']:
        validator_func(counter, log)
        counter += 1

    print('SUCCESS: ' + test_name)
    return True


def vanilla_validator(counter, log):
    event = json.loads(log['message'])
    val = int(event['log'])
    if val != counter:
        print('Expected: ' + str(counter) + '; Found: ' + str(val))
        sys.exit('TEST_FAILURE: found out of order log message')


def log_key_validator(counter, log):
    # TODO: .strip could be unneeded in the future: https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/14
    val = int(log['message'].strip('\"'))
    if val != counter:
        print('Expected: ' + str(counter) + '; Found: ' + str(val))
        sys.exit('TEST_FAILURE: found out of order log message')


def validate_metric(test_name, metric_namespace, dim_key, dim_value, expected_samples=1):
    attempts = 0
    max_attempts = 20
    while attempts < max_attempts:
        if metric_exists(metric_namespace, dim_key, dim_value, expected_samples):
            print('SUCCESS: ' + test_name)
            return True
        attempts += 1
        print(f"No metrics yet. Sleeping before trying again. Attempt # {attempts}")
        time.sleep(2)

    sys.exit('TEST_FAILURE: failed to validate metric existence in CloudWatch')


def metric_exists(metric_namespace, dim_key, dim_value, expected_samples):
    metric_name = get_expected_metric_name()
    response = metrics_client.get_metric_statistics(
        Namespace=metric_namespace,
        MetricName=metric_name,
        Dimensions=[{"Name": dim_key, "Value": dim_value}],
        StartTime=start_time,
        EndTime=end_time,
        Period=60,
        Statistics=["SampleCount", "Average"],
        Unit="None",
    )

    total_samples = 0
    for datapoint in response["Datapoints"]:
        total_samples += datapoint["SampleCount"]

    if total_samples == expected_samples:
        return True
    elif total_samples > expected_samples:
        print(f"Too many datapoints returned. Expected {expected_samples}, received {total_samples}")
    else:
        print(response["Datapoints"])
    print(f"Did not find {metric_namespace}/{metric_name}/{dim_key}:{dim_value}")
    return False

    
def get_expected_metric_name():
    with open(os.environ.get('EMF_METRIC_NAME_PATH'), 'r') as file:
        return file.read().replace('\n', '')

tag = os.environ.get('TAG')
# CW Test Case 1: Simple/Basic Configuration, Log message is JSON
success_case_1 = validate_test_case('CW Test 1: Basic Config', LOG_GROUP_NAME, 'from-fluent-bit-basic-test-' + tag, vanilla_validator)

# CW Test Case 2: tests 'log_key' option, Log message is just the stdout output (a number)
success_case_2 = validate_test_case('CW Test 2: log_key option', LOG_GROUP_NAME, 'from-fluent-bit-log-key-test-' + tag, log_key_validator)

success_case_emf = validate_metric('CW Test 3: EMF metrics', 'fluent-metrics', 'dimensionKey', 'dimensionValue')

if success_case_1 and success_case_2 and success_case_emf:
    # if this file is still present, integ script will mark the test as a failure
    os.remove("/out/cloudwatch-test")
