# re-runs test cases that failed
# separator.py can be used to parse out the failed runs per region
# then this can be used to re-validate each run

# this was necessary because initial runs suffered from CW eventually consistency
# with no sleep at start of validator, some records were reported as missing that were
# actually sent 

# this script has some duplicated code copied from analyze.py
# since this framework is not currently planned to be used many times

# test_run_checker.py <validator executable path> <input data>

import csv
import sys
import os
import subprocess

# I should have made the buffer size an env var and printed in the result
# instead its part of the test name
TEST_NAMES_TO_BUFFER_SIZES = {
    'DEFAULT_BUFFER': 1,
    '2M_BUFFER': 2,
    '2MB_BUFFER': 2,
    '1m_BUFFER': 1,
    '2m_BUFFER': 2,
    '3m_BUFFER': 3,
    '4m_BUFFER': 4,
    '5m_BUFFER': 5,
    '6m_BUFFER': 6,
    '7m_BUFFER': 7,
    '8m_BUFFER': 8,
    '9m_BUFFER': 9,
    '10m_BUFFER': 10,
    '11m_BUFFER': 11,
    '12m_BUFFER': 12,
    '15m_BUFFER': 15,
    '20m_BUFFER': 20,
    '25m_BUFFER': 25,
    '30m_BUFFER': 30,
    '40m_BUFFER': 40,
    '50m_BUFFER': 50,
    '60m_BUFFER': 60,
    '75m_BUFFER': 75,
    '100m_BUFFER': 100,
    '150m_BUFFER': 150,
    '200m_BUFFER': 200,
}

task_ids_found = {}

def validate_test_run(test_run):
    if len(test_run) < 16:
        return 'len'
    if 'percent lost' not in test_run[1]:
        return 'percent lost'
    if 'number_lost' not in test_run[3]:
        return 'number_lost'
    if 'total_input_record' not in test_run[5]:
        return 'total_input_record'
    # early version of validator has this env var printed out with wrong name
    if 'SIZE_IN_MB' not in test_run[10] and 'SIZE_IN_KB' not in test_run[10]:
        return 'SIZE_IN_MB/SIZE_IN_KB'
    if 'THROUGHPUT_IN_KB' not in test_run[11]:
        return 'THROUGHPUT_IN_KB'
    if 'FARGATE' not in test_run[15] and 'EC2' not in test_run[15]:
        return 'LAUNCH_TYPE'
    return ""

def process_test_run(test_run):
    global task_ids_found
    test_name = test_run[0].strip().split()[0]
    percent_lost = test_run[2].strip()
    number_lost = test_run[4].strip()
    success = False
    if number_lost == "0":
        success = True
    tmp = test_run[10].strip()
    split = tmp.split("=")
    log_size = split[1]
    tmp = test_run[11].strip()
    split = tmp.split("=")
    throughput = int(split[1])
    task_id = test_run[12].strip()
    cluster = test_run[13].strip()
    if '/' in cluster: # some output has cluster ARN, some just name, not sure why
        split = cluster.split("/")
        cluster = split[1]
    task_def = test_run[14].strip()
    launch_type = test_run[15].strip()
    region = test_run[16].strip()
    buffer_size = 0
    for pattern in TEST_NAMES_TO_BUFFER_SIZES:
        if pattern in test_name:
            buffer_size = TEST_NAMES_TO_BUFFER_SIZES[pattern]

    if buffer_size == 0:
        print("could not find buffer size in " + test_name)
        return None

    log_group = ""
    total_mb = ""
    grouped_data = test_run[9].strip()
    kv_data = grouped_data.split()
    for data in kv_data:
        kv = data.split('=')
        if kv[0] == 'group':
            log_group = kv[1]
        if kv[0] == 'TOTAL_SIZE_IN_MB':
            total_mb = kv[1]
    log_stream = os.environ.get('CW_LOG_STREAM_PREFIX', 'pre-testing-bug/logger/') + task_id

    # use task ID to guard against duplicate test results pasted into the output due to human error
    if task_ids_found.get(task_id):
        print("ERROR: duplicate test run "+ test_name)
        return None
    task_ids_found[task_id] = True
    return {
        'test_name': test_name,
        'success': success,
        'loss_%': percent_lost,
        'number_lost': number_lost,
        'log_size': log_size,
        'throughput': throughput,
        'cluster': cluster,
        'launch_type': launch_type,
        'buffer': buffer_size,
        'task_id': task_id,
        'task_def': task_def,
        'region': region,
        'log_group': log_group,
        'log_stream': log_stream,
        'total_mb': total_mb,
    }

# subprocess.run(["/Users/wppttt/logging-projects/aws-for-fluent-bit/troubleshooting/tools/log-loss-test-framework/validator/cw-log-loss-validator"], capture_output=True, env=cmd_env)
# https://docs.python.org/3/library/subprocess.html#subprocess.run


def re_validate(test_run):
    cmd_env = dict(os.environ)   # Make a copy of the current environment
    cmd_env['AWS_REGION'] = test_run['region']
    cmd_env['CW_LOG_GROUP_NAME'] = test_run['log_group']
    cmd_env['CW_LOG_STREAM_NAME'] = test_run['log_stream']
    cmd_env['TOTAL_SIZE_IN_MB'] = test_run['total_mb']
    cmd_env['SIZE_IN_KB'] = test_run['log_size']
    cmd_env['THROUGHPUT_IN_KB'] = str(test_run['throughput'])
    cmd_env['TEST_NAME'] = test_run['test_name']
    cmd_env['ECS_TASK_DEFINITION'] = test_run['task_def']
    cmd_env['ECS_CLUSTER'] = test_run['cluster']
    cmd_env['ECS_TASK_ID'] = test_run['task_id']
    cmd_env['ECS_LAUNCH_TYPE'] = test_run['launch_type']
    cmd_env['HISTOGRAM'] = 'On'

    subprocess.run([sys.argv[1]], capture_output=False, env=cmd_env)
    # result = subprocess.run([sys.argv[1]], capture_output=True, env=cmd_env, encoding='utf-8')
    # for line in result.stdout.split('\n'):
    #     print(line)

all_test_runs = []


with open(sys.argv[2]) as csv_file:
    csv_reader = csv.reader(csv_file, delimiter=',')
    line_count = 0
    for row in csv_reader:
        line_count += 1
        test_run = list(row)
        err = validate_test_run(test_run)
        if err != "":
            print("INVALID DATA: NOT FOUND: " + err + ",  --\n  " + ", ".join(test_run))
            continue
        if 'BUG' in test_run[0]: # skip AWSLogs non-blocking bug test runs
            continue

        data = process_test_run(test_run)
        if data == None:
            print("INVALID DATA: " + ", ".join(test_run))
            continue

        all_test_runs.append(data)

    print(f'Processed {line_count} test runs')

    for test_run in all_test_runs:
        re_validate(test_run)


