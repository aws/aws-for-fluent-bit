import boto3
import json
import sys
import os


client = boto3.client('logs', region_name=os.environ.get('AWS_REGION'))
LOG_GROUP_NAME = os.environ.get('LOG_GROUP_NAME')

def validate_test_case(test_name, log_group, log_stream, validator_func):
    print('RUNNING: ' + test_name)
    response = client.get_log_events(logGroupName=log_group,logStreamName=log_stream)
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


tag = os.environ.get('TAG')
# CW Test Case 1: Simple/Basic Configuration, Log message is JSON
success_case_1 = validate_test_case('CW Test 1: Basic Config', LOG_GROUP_NAME, 'from-fluent-bit-basic-test-' + tag, vanilla_validator)

# CW Test Case 2: tests 'log_key' option, Log message is just the stdout output (a number)
success_case_2 = validate_test_case('CW Test 2: log_key option', LOG_GROUP_NAME, 'from-fluent-bit-log-key-test-' + tag, log_key_validator)

if success_case_1 and success_case_2:
    # if this file is still present, integ script will mark the test as a failure
    os.remove("/out/cloudwatch-test")
