import boto3
import json
import sys
import os
import time
from datetime import datetime, timedelta

client = boto3.client('logs', region_name=os.environ.get('AWS_REGION'))
metrics_client = boto3.client("cloudwatch", region_name=os.environ["AWS_REGION"])
# time range for EMF metric query
start_time = datetime.utcnow() - timedelta(seconds=1200)
end_time = datetime.utcnow() + timedelta(seconds=30)

LOG_GROUP_NAME = os.environ.get('LOG_GROUP_NAME')


def execute_with_retry(max_retry_attempts, retriable_function, *argv):
    retry_time_secs = 10
    attempt = 0

    while attempt < max_retry_attempts:
        success, ret_message = retriable_function(*argv)
        # If we succeed, then return the success response.
        if success:
            return True

        # If we fail, then increment the attempt and sleep for the specified time.
        print(ret_message +
              '. Current retry attempt: ' + str(attempt) +
              '. Max retry attempt: ' + str(max_retry_attempts))
        attempt += 1
        time.sleep(retry_time_secs)

    sys.exit(retriable_function.__name__ + ' failed after exhaustion of retry limit.')


def validate_test_case(test_name, log_group, log_stream, validator_func):
    print('RUNNING: ' + test_name)
    try: 
        response = client.get_log_events(logGroupName=log_group, logStreamName=log_stream)
    except Exception as e:
        print(e)
        return False, 'TEST_FAILURE: API call failed'
        
    # test length
    if len(response['events']) != 1000:
        print(str(len(response['events'])) + ' events found in CloudWatch')
        return False, 'TEST_FAILURE: incorrect number of log events found'

    counter = 0
    for log in response['events']:
        success, ret_message = validator_func(counter, log)
        if not success:
            return False, ret_message

        counter += 1

    print('SUCCESS: ' + test_name)
    return True, 'Success'


def vanilla_validator(counter, log):
    event = json.loads(log['message'])
    val = int(event['log'])
    if val != counter:
        print('Expected: ' + str(counter) + '; Found: ' + str(val))
        return False, 'TEST_FAILURE: found out of order log message'
    return True, 'Success'


def log_key_validator(counter, log):
    # TODO: .strip could be unneeded in the future: https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/14
    val = int(log['message'].strip('\"'))
    if val != counter:
        print('Expected: ' + str(counter) + '; Found: ' + str(val))
        return False, 'TEST_FAILURE: found out of order log message'
    return True, 'Success'


def validate_metric(test_name, metric_namespace, dim_key, dim_value, expected_samples=1):
    print('RUNNING: ' + test_name)
    if metric_exists(metric_namespace, dim_key, dim_value, expected_samples):
        print('SUCCESS: ' + test_name)
        return True, 'Success'

    return False, 'TEST_FAILURE: failed to validate metric existence in CloudWatch'


def metric_exists(metric_namespace, dim_key, dim_value, expected_samples):
    metric_name = get_expected_metric_name()
    try:
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
    except Exception as e:
        print(e)
        return False

    if response is None:
        return False

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
print('Tag for current run is: ' + tag)
# CW Test Case 1: Simple/Basic Configuration, Log message is JSON
success_case_1 = execute_with_retry(5,
                                    validate_test_case,
                                    'CW Test 1: Basic Config',
                                    LOG_GROUP_NAME,
                                    'from-fluent-bit-basic-test-' + tag,
                                    vanilla_validator)

# CW Test Case 2: tests 'log_key' option, Log message is just the stdout output (a number)
success_case_2 = execute_with_retry(5,
                                    validate_test_case,
                                    'CW Test 2: log_key option',
                                    LOG_GROUP_NAME,
                                    'from-fluent-bit-log-key-test-' + tag,
                                    log_key_validator)

success_case_emf = execute_with_retry(25,
                                      validate_metric,
                                      'CW Test 3: EMF metrics',
                                      'fluent-metrics',
                                      'dimensionKey',
                                      'dimensionValue')

if success_case_1 and success_case_2 and success_case_emf:
    # if this file is still present, integ script will mark the test as a failure
    os.remove("/out/cloudwatch-test")
