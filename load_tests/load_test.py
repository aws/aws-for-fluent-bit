import os
import sys
import json
import time
import boto3
import subprocess
from datetime import datetime, timezone

PLATFORM = os.environ['PLATFORM']
OUTPUT_PLUGIN = os.environ['OUTPUT_PLUGIN'].lower()
TESTING_RESOURCES_STACK_NAME = os.environ['TESTING_RESOURCES_STACK_NAME']
PREFIX = os.environ['PREFIX']
LOGGER_RUN_TIME_IN_SECOND = 600
BUFFER_TIME_IN_SECOND = 300
if OUTPUT_PLUGIN == 'cloudwatch':
    THROUGHPUT_LIST = json.loads(os.environ['CW_THROUGHPUT_LIST'])
else:
    THROUGHPUT_LIST = json.loads(os.environ['THROUGHPUT_LIST'])

# Return the approximate log delay for each ecs load test
# Estimate log delay = task_stop_time - task_start_time - logger_image_run_time
def get_log_delay(response):
    stop_time = response['tasks'][0]['stoppedAt']
    stop_epoch_time = (stop_time - datetime(1970,1,1, tzinfo=timezone.utc)).total_seconds()
    start_time = response['tasks'][0]['startedAt']
    start_epoch_time = (start_time - datetime(1970,1,1, tzinfo=timezone.utc)).total_seconds()

    log_delay_epoch_time = stop_epoch_time - start_epoch_time - LOGGER_RUN_TIME_IN_SECOND
    return datetime.fromtimestamp(log_delay_epoch_time).strftime('%Mm%Ss')

# Set buffer for waiting all logs sent to destinations (~5min)
def set_buffer(response):
    stop_time = response['tasks'][0]['stoppedAt']
    stop_epoch_time = (stop_time - datetime(1970,1,1, tzinfo=timezone.utc)).total_seconds()
    curr_epoch_time = time.time()
    if curr_epoch_time-stop_epoch_time < BUFFER_TIME_IN_SECOND:
        time.sleep(int(BUFFER_TIME_IN_SECOND-curr_epoch_time+stop_epoch_time))

# Check app container exit status for each ecs load test
# to make sure it generate correct number of logs
def check_app_exit_code(response):
    containers = response['tasks'][0]['containers']
    if len(containers) < 2:
        sys.exit('[TEST_FAILURE] Error occured to get task container list')
    for container in containers:
        if container['name'] == 'app' and container['exitCode'] != 0:
            sys.exit('[TEST_FAILURE] Logger failed to generate all logs with exit code: ', container['exitCode'])

# Return the total number of input records for each load test
def calculate_total_input_number(throughput):
    iteration_per_second = int(throughput[0:-1])*1000
    return str(iteration_per_second * LOGGER_RUN_TIME_IN_SECOND)

# 1. Configure task definition for each load test based on existing templates
# 2. Register generated task definition
def generate_task_definition(throughput):
    task_definition_dict = {
        '$THROUGHPUT': throughput,
        '$TASK_ROLE_ARN': os.environ['LOAD_TEST_TASK_ROLE_ARN'],
        '$TASK_EXECUTION_ROLE_ARN': os.environ['LOAD_TEST_TASK_EXECUTION_ROLE_ARN'],
        '$FLUENT_BIT_IMAGE': os.environ['FLUENT_BIT_IMAGE'],
        '$APP_IMAGE': os.environ['APP_IMAGE'],
        '$LOGGER_RUN_TIME_IN_SECOND': str(LOGGER_RUN_TIME_IN_SECOND),
        'cloudwatch': {'$CW_LOG_GROUP_NAME': os.environ['CW_LOG_GROUP_NAME']},
        'firehose': {'$DELIVERY_STREAM': os.environ[f'FIREHOSE_TEST_{throughput}']},
        'kinesis': {'$STREAM': os.environ[f'KINESIS_TEST_{throughput}']},
        's3': {'$S3_BUCKET_NAME': os.environ['S3_BUCKET_NAME']},
    }
    fin = open(f'./load_tests/task_definitions/{OUTPUT_PLUGIN}.json', 'r')
    data = fin.read()
    for key in task_definition_dict:
        if(key[0] == '$'):
            data = data.replace(key, task_definition_dict[key])
        elif(key == OUTPUT_PLUGIN):
            for sub_key in task_definition_dict[key]:
                data = data.replace(sub_key, task_definition_dict[key][sub_key])
    fout = open(f'./load_tests/task_definitions/{OUTPUT_PLUGIN}_{throughput}.json', 'w')
    fout.write(data)
    fout.close()
    fin.close()
    os.system(f'aws ecs register-task-definition --cli-input-json file://load_tests/task_definitions/{OUTPUT_PLUGIN}_{throughput}.json')

# With multiple codebuild projects running parallel,
# Testing resources only needs to be created once
def create_testing_resources():
    if OUTPUT_PLUGIN != 'cloudwatch':
        client = boto3.client('cloudformation')
        waiter = client.get_waiter('stack_exists')
        waiter.wait(
            StackName=TESTING_RESOURCES_STACK_NAME,
            WaiterConfig={
                'MaxAttempts': 60
            }
        )
        waiter = client.get_waiter('stack_create_complete')
        waiter.wait(
            StackName=TESTING_RESOURCES_STACK_NAME
        )
    else:
        # Once deployment starts, it will wait until the stack creation is completed
        os.chdir(f'./load_tests/{sys.argv[1]}')
        os.system('cdk deploy --require-approval never')

# For tests on ECS, we need to:
#  1. generate and register task definitions based on templates at /load_tests/task_definitons
#  2. run tasks with different throughput levels for 10 mins
#  3. wait until tasks completed, set buffer for logs sent to corresponding destinations
#  4. validate logs and print the result
def run_ecs_tests():
    ecs_cluster_name = os.environ['ECS_CLUSTER_NAME']
    client = boto3.client('ecs')
    waiter = client.get_waiter('tasks_stopped')
    processes = set()
    names = locals()

    # Run ecs tasks and store task arns
    for throughput in THROUGHPUT_LIST:
        os.environ['THROUGHPUT'] = throughput
        generate_task_definition(throughput)
        response = client.run_task(
                cluster=ecs_cluster_name,
                launchType='EC2',
                taskDefinition=f'{PREFIX}{OUTPUT_PLUGIN}-{throughput}'
        )
        names[f'{OUTPUT_PLUGIN}_{throughput}_task_arn'] = response['tasks'][0]['taskArn']

    # Wait until task stops and start validation
    for throughput in THROUGHPUT_LIST:
        waiter.wait(
            cluster=ecs_cluster_name,
            tasks=[
                names[f'{OUTPUT_PLUGIN}_{throughput}_task_arn'],
            ],
            WaiterConfig={
                'MaxAttempts': 600
            }
        )
        response = client.describe_tasks(
            cluster=ecs_cluster_name,
            tasks=[
                names[f'{OUTPUT_PLUGIN}_{throughput}_task_arn'],
            ]
        )
        check_app_exit_code(response)
        input_record = calculate_total_input_number(throughput)
        log_delay = get_log_delay(response)
        set_buffer(response)
        # Validate logs
        if OUTPUT_PLUGIN == 'cloudwatch':
            os.environ['LOG_PREFIX'] = throughput
            os.environ['DESTINATION'] = 'cloudwatch'
        else:
            os.environ['LOG_PREFIX'] = f'{OUTPUT_PLUGIN}-test/ecs/{throughput}/'
            os.environ['DESTINATION'] = 's3'
        processes.add(subprocess.Popen(['go', 'run', './load_tests/validation/validate.go', input_record, log_delay]))
    
    # Wait until all subprocesses for validation completed
    for p in processes:
        p.wait()

def delete_testing_resources():
    # All related testing resources will be destroyed once the stack is deleted 
    client = boto3.client('cloudformation')
    client.delete_stack(
        StackName=TESTING_RESOURCES_STACK_NAME
    )
    # Empty s3 bucket
    s3 = boto3.resource('s3')
    bucket = s3.Bucket(os.environ['S3_BUCKET_NAME'])
    bucket.objects.all().delete()

if sys.argv[1] == 'create_testing_resources':
    create_testing_resources()
elif sys.argv[1] == 'ECS':
    run_ecs_tests()
elif sys.argv[1] == 'delete_testing_resources':
    # testing resources only need to be deleted once
    if OUTPUT_PLUGIN == 'cloudwatch':
        delete_testing_resources()