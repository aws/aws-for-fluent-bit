import os
import sys
import json
import time
import boto3
import math
import subprocess
import validation_bar
from datetime import datetime, timezone
import create_testing_resources.kinesis_s3_firehose.resource_resolver as resource_resolver

IS_TASK_DEFINITION_PRINTED = True
PLATFORM = os.environ['PLATFORM'].lower()
OUTPUT_PLUGIN = os.environ['OUTPUT_PLUGIN'].lower()
TESTING_RESOURCES_STACK_NAME = os.environ['TESTING_RESOURCES_STACK_NAME']
PREFIX = os.environ['PREFIX']
EKS_CLUSTER_NAME = os.environ['EKS_CLUSTER_NAME']
LOGGER_RUN_TIME_IN_SECOND = 600
BUFFER_TIME_IN_SECOND = 300
NUM_OF_EKS_NODES = 4
if OUTPUT_PLUGIN == 'cloudwatch':
    THROUGHPUT_LIST = json.loads(os.environ['CW_THROUGHPUT_LIST'])
else:
    THROUGHPUT_LIST = json.loads(os.environ['THROUGHPUT_LIST'])

# Input Logger Data
INPUT_LOGGERS = [
    {
        "name": "stdstream",
        "logger_image": os.getenv('ECS_APP_IMAGE'), # STDOUT Logs
        "fluent_config_file_path": "./load_tests/logger/stdout_logger/fluent.conf",
        "log_configuration_path": "./load_tests/logger/stdout_logger/log_configuration"
    },
    {
        "name": "tcp",
        "logger_image": os.getenv('ECS_APP_IMAGE_TCP'), # TCP Logs Java App
        "fluent_config_file_path": "./load_tests/logger/tcp_logger/fluent.conf",
        "log_configuration_path": "./load_tests/logger/tcp_logger/log_configuration"
    },
]

PLUGIN_NAME_MAPS = {
    "kinesis": "kinesis_streams",
    "firehose": "kinesis_firehose",
    "s3": "s3",
    "cloudwatch": "cloudwatch_logs",
}

# Return the approximate log delay for each ecs load test
# Estimate log delay = task_stop_time - task_start_time - logger_image_run_time
def get_log_delay(log_delay_epoch_time):
    return datetime.fromtimestamp(log_delay_epoch_time).strftime('%Mm%Ss')

# Set buffer for waiting all logs sent to destinations (~5min)
def set_buffer(stop_epoch_time):
    curr_epoch_time = time.time()
    if curr_epoch_time-stop_epoch_time < BUFFER_TIME_IN_SECOND:
        time.sleep(int(BUFFER_TIME_IN_SECOND-curr_epoch_time+stop_epoch_time))

# convert datetime to epoch time
def parse_time(time):
    return (time - datetime(1970,1,1, tzinfo=timezone.utc)).total_seconds()

# Check app container exit status for each ecs load test
# to make sure it generate correct number of logs
def check_app_exit_code(response):
    containers = response['tasks'][0]['containers']
    if len(containers) < 2:
        sys.exit('[TEST_FAILURE] Error occured to get task container list')
    for container in containers:
        if container['name'] == 'app' and container['exitCode'] != 0:
            print('[TEST_FAILURE] Logger failed to generate all logs with exit code: ' + str(container['exitCode']))
            sys.exit('[TEST_FAILURE] Logger failed to generate all logs with exit code: ' + str(container['exitCode']))

# Return the total number of input records for each load test
def calculate_total_input_number(throughput):
    iteration_per_second = int(throughput[0:-1])*1000
    return str(iteration_per_second * LOGGER_RUN_TIME_IN_SECOND)

# 1. Configure task definition for each load test based on existing templates
# 2. Register generated task definition
def generate_task_definition(session, throughput, input_logger, s3_fluent_config_arn):
    if not hasattr(generate_task_definition, "counter"):
        generate_task_definition.counter = 0  # it doesn't exist yet, so initialize it
    generate_task_definition.counter += 1

    # Generate configuration information for STD and TCP tests
    std_config      = resource_resolver.get_input_configuration(PLATFORM, resource_resolver.STD_INPUT_PREFIX, throughput)
    custom_config   = resource_resolver.get_input_configuration(PLATFORM, resource_resolver.CUSTOM_INPUT_PREFIX, throughput)

    task_definition_dict = {

        # App Container Environment Variables
        '$APP_IMAGE': input_logger['logger_image'],
        '$LOGGER_RUN_TIME_IN_SECOND': str(LOGGER_RUN_TIME_IN_SECOND),
        
        # Firelens Container Environment Variables
        '$FLUENT_BIT_IMAGE': os.environ['FLUENT_BIT_IMAGE'],
        '$INPUT_NAME': input_logger['name'],
        '$LOGGER_PORT': "4560",
        '$FLUENT_CONFIG_S3_FILE_ARN': s3_fluent_config_arn,
        '$OUTPUT_PLUGIN': OUTPUT_PLUGIN,

        # General Environment Variables
        '$THROUGHPUT': throughput,

        # Task Environment Variables
        '$TASK_ROLE_ARN': os.environ['LOAD_TEST_TASK_ROLE_ARN'],
        '$TASK_EXECUTION_ROLE_ARN': os.environ['LOAD_TEST_TASK_EXECUTION_ROLE_ARN'],
        '$CUSTOM_S3_OBJECT_NAME':           resource_resolver.resolve_s3_object_name(custom_config),

        # Plugin Specific Environment Variables
        'cloudwatch': {
            '$CW_LOG_GROUP_NAME':               os.environ['CW_LOG_GROUP_NAME'],
            '$STD_LOG_STREAM_NAME':             resource_resolver.resolve_cloudwatch_logs_stream_name(std_config),
            '$CUSTOM_LOG_STREAM_NAME':          resource_resolver.resolve_cloudwatch_logs_stream_name(custom_config)
        },
        'firehose': {
            '$STD_DELIVERY_STREAM_PREFIX':      resource_resolver.resolve_firehose_delivery_stream_name(std_config),
            '$CUSTOM_DELIVERY_STREAM_PREFIX':   resource_resolver.resolve_firehose_delivery_stream_name(custom_config),
        },
        'kinesis': {
            '$STD_STREAM_PREFIX':               resource_resolver.resolve_kinesis_delivery_stream_name(std_config),
            '$CUSTOM_STREAM_PREFIX':            resource_resolver.resolve_kinesis_delivery_stream_name(custom_config),
        },
        's3': {
            '$S3_BUCKET_NAME':                  os.environ['S3_BUCKET_NAME'],
            '$STD_S3_OBJECT_NAME':              resource_resolver.resolve_s3_object_name(std_config),
        },
    }

    # Add log configuration to dictionary
    log_configuration_data = open(f'{input_logger["log_configuration_path"]}/{OUTPUT_PLUGIN}.json', 'r')
    log_configuration_raw = log_configuration_data.read()
    log_configuration = parse_json_template(log_configuration_raw, task_definition_dict)
    task_definition_dict["$LOG_CONFIGURATION"] = log_configuration

    # Parse task definition template
    fin = open(f'./load_tests/task_definitions/{OUTPUT_PLUGIN}.json', 'r')
    data = fin.read()
    task_def_formatted = parse_json_template(data, task_definition_dict)

    # Register task definition
    task_def = json.loads(task_def_formatted)
    
    if IS_TASK_DEFINITION_PRINTED:
        print("Registering task definition:")
        print(json.dumps(task_def, indent=4))
        session.client('ecs').register_task_definition(
            **task_def
        )
    else:
        print("Registering task definition")

# With multiple codebuild projects running parallel,
# Testing resources only needs to be created once
def create_testing_resources():
    session = get_sts_boto_session()

    if OUTPUT_PLUGIN != 'cloudwatch':
        client = session.client('cloudformation')
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
        # scale up eks cluster 
        if PLATFORM == 'eks':
            os.system(f'eksctl scale nodegroup --cluster={EKS_CLUSTER_NAME} --nodes={NUM_OF_EKS_NODES} ng')
            while True:
                time.sleep(90)
                number_of_nodes = subprocess.getoutput("kubectl get nodes --no-headers=true | wc -l")
                if(int(number_of_nodes) == NUM_OF_EKS_NODES):
                    break
            # create namespace
            os.system('kubectl apply -f ./load_tests/create_testing_resources/eks/namespace.yaml')
        # Once deployment starts, it will wait until the stack creation is completed
        os.chdir(f'./load_tests/{sys.argv[1]}/{PLATFORM}')
        os.system('cdk deploy --require-approval never')

# For tests on ECS, we need to:
#  1. generate and register task definitions based on templates at /load_tests/task_definitons
#  2. run tasks with different throughput levels for 10 mins
#  3. wait until tasks completed, set buffer for logs sent to corresponding destinations
#  4. validate logs and print the result
def run_ecs_tests():
    ecs_cluster_name = os.environ['ECS_CLUSTER_NAME']
    names = locals()

    # Run ecs tests once per input logger type
    test_results = []
    for input_logger in INPUT_LOGGERS:
        session = get_sts_boto_session()

        client = session.client('ecs')
        waiter = client.get_waiter('tasks_stopped')
        
        processes = []

        # Delete corresponding testing data for a fresh start
        delete_testing_data(session)

        # S3 Fluent Bit extra config data
        s3_fluent_config_arn = publish_fluent_config_s3(session, input_logger)

        # Run ecs tasks and store task arns
        for throughput in THROUGHPUT_LIST:
            os.environ['THROUGHPUT'] = throughput
            generate_task_definition(session, throughput, input_logger, s3_fluent_config_arn)
            response = client.run_task(
                    cluster=ecs_cluster_name,
                    launchType='EC2',
                    taskDefinition=f'{PREFIX}{OUTPUT_PLUGIN}-{throughput}'
            )
            names[f'{OUTPUT_PLUGIN}_{throughput}_task_arn'] = response['tasks'][0]['taskArn']
        
        # Validation input type banner
        print(f'\nTest {input_logger["name"]} to {OUTPUT_PLUGIN} in progress...')

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
            start_time = response['tasks'][0]['startedAt']
            stop_time = response['tasks'][0]['stoppedAt']
            log_delay = get_log_delay(parse_time(stop_time)-parse_time(start_time)-LOGGER_RUN_TIME_IN_SECOND)
            set_buffer(parse_time(stop_time))

            # Validate logs
            os.environ['LOG_SOURCE_NAME'] = input_logger["name"]
            os.environ['LOG_SOURCE_IMAGE'] = input_logger["logger_image"]
            validated_input_prefix = get_validated_input_prefix(input_logger)
            input_configuration = resource_resolver.get_input_configuration(PLATFORM, validated_input_prefix, throughput)
            test_configuration = {
                "input_configuration": input_configuration,
            }
            if OUTPUT_PLUGIN == 'cloudwatch':
                os.environ['LOG_PREFIX'] = resource_resolver.get_destination_cloudwatch_prefix(test_configuration["input_configuration"])
                os.environ['DESTINATION'] = 'cloudwatch'
            else:
                os.environ['LOG_PREFIX'] = resource_resolver.get_destination_s3_prefix(test_configuration["input_configuration"], OUTPUT_PLUGIN)
                os.environ['DESTINATION'] = 's3'

            # Go script environment with sts cred variables
            credentials = session.get_credentials()
            auth_env = {
                **os.environ.copy(),
                "AWS_ACCESS_KEY_ID": credentials.access_key,
                "AWS_SECRET_ACCESS_KEY": credentials.secret_key,
                "AWS_SESSION_TOKEN": credentials.token
            }
            processes.append({
                "input_logger": input_logger,
                "test_configuration": test_configuration,
                "process": subprocess.Popen(['go', 'run', './load_tests/validation/validate.go', input_record, log_delay], stdout=subprocess.PIPE,
                    env=auth_env
                )
            })

        # Wait until all subprocesses for validation completed
        for p in processes:
            p["process"].wait()
            p["result"], err = p["process"].communicate()
        print(f'Test {input_logger["name"]} to {OUTPUT_PLUGIN} complete.')

        parsedValidationOutputs = list(map(lambda p: {
            **p,
            "parsed_validation_output": parse_validation_output(p["result"])
        }, processes))

        test_results.extend(parsedValidationOutputs)

        # Wait for task resources to free up
        time.sleep(60)

    # Print output
    print("\n\nValidation results:\n")
    print(format_test_results_to_markdown(test_results))

    # Bar check
    if not validation_bar.bar_raiser(test_results):
        print("Failed validation bar.")
        sys.exit("Failed to pass the test_results validation bar")
    else:
        print("Passed validation bar.")

def parse_validation_output(validationResultString):
    return { x[0]: x[1] for x in list(
        filter(lambda f: len(f) == 2,
            map(lambda x: x.split(",  "), validationResultString.decode("utf-8").split("\n"))
        ))}

def get_validation_output(logger_name, throughput, test_results):
    return list(filter(lambda r: r["input_logger"]["name"] == logger_name and
            int(r["test_configuration"]["input_configuration"]["throughput"].replace("m", "")) == throughput, test_results))[0]["parsed_validation_output"]

def format_test_results_to_markdown(test_results):
    # Configurable success character
    no_problem_cell_character = u"\U00002705" # This is a green check mark

    # Get table dimensions
    logger_names = list(set(map(lambda p: p["input_logger"]["name"], test_results)))
    logger_names.sort()
    plugin_name = PLUGIN_NAME_MAPS[OUTPUT_PLUGIN]
    throughputs = list(set(map(lambda p: int(p["test_configuration"]["input_configuration"]["throughput"].replace("m", "")), test_results)))
    throughputs.sort()

    # | plugin                   | source               |                            | 10 MB/s       | 20 MB/s       | 30 MB/s       |\n"
    # |--------------------------|----------------------|----------------------------|---------------|---------------|---------------|\n"
    col1_len = len(" plugin                   ")
    col2_len = len(" source               ")
    col3_len = len("                            ")
    colX_len = len(" 10 MB/s       ")

    output  = f'|{" plugin".ljust(col1_len)}|{" source".ljust(col2_len)}|{"".ljust(col3_len)}|'
    for throughput in throughputs:
        output += (" " + str(throughput) + " MB/s").ljust(colX_len) + "|"
    output += f"\n|{'-'*col1_len}|{'-'*col2_len}|{'-'*col3_len}|"
    for throughput in throughputs:
        output += f"{'-'*colX_len}|"
    output += "\n"

    # | kinesis_firehose          |  stdout             | Log Loss                   |               |               |               |\n"
    for logger_name in logger_names:
        output += "|"
        output += (" " + plugin_name).ljust(col1_len) + "|"
        output += (" " + logger_name).ljust(col2_len) + "|"
        output += (" Log Loss").ljust(col3_len) + "|"

        for throughput in throughputs:
            validation_output = get_validation_output(logger_name, throughput, test_results)

            if (int(validation_output["missing"]) != 0):
                output += (str(validation_output["percent_loss"]) + "%(" + str(validation_output["missing"]) + ")").ljust(colX_len)
            else:
                output += (" " + no_problem_cell_character).ljust(colX_len)

            output += "|"
        output += "\n"

        output += "|"
        output += (" ").ljust(col1_len) + "|"
        output += (" ").ljust(col2_len) + "|"
        output += (" Log Duplication").ljust(col3_len) + "|"

        for throughput in throughputs:
            validation_output = get_validation_output(logger_name, throughput, test_results)

            duplication_percent = (0 if int(validation_output["duplicate"]) == 0
                else math.floor(int(validation_output["duplicate"]) / int(validation_output["total_destination"]) * 100))

            if (int(validation_output["duplicate"]) != 0):
                output += (str(duplication_percent) + "%(" + str(validation_output["duplicate"]) + ")").ljust(colX_len)
            else:
                output += (" " + no_problem_cell_character).ljust(colX_len)

            output += "|"
        output += "\n"
    return output

def parse_json_template(template, dict):
    data = template
    for key in dict:
            if(key[0] == '$'):
                data = data.replace(key, dict[key])
            elif(key == OUTPUT_PLUGIN):
                for sub_key in dict[key]:
                    data = data.replace(sub_key, dict[key][sub_key])
    return data

# Returns s3 arn
def publish_fluent_config_s3(session, input_logger):
    bucket_name = os.environ['S3_BUCKET_NAME']
    s3 = session.client('s3')
    s3.upload_file(
        input_logger["fluent_config_file_path"],
        bucket_name,
        f'{OUTPUT_PLUGIN}-test/{PLATFORM}/fluent-{input_logger["name"]}.conf',
    )
    return f'arn:aws:s3:::{bucket_name}/{OUTPUT_PLUGIN}-test/{PLATFORM}/fluent-{input_logger["name"]}.conf'

# The following method is used to clear data between
# testing batches
def delete_testing_data(session):
    # All testing data related to the plugin option will be deleted
    if OUTPUT_PLUGIN == 'cloudwatch':
        # Delete associated cloudwatch log streams
        client = session.client('logs')
        response = client.describe_log_streams(
            logGroupName=os.environ['CW_LOG_GROUP_NAME']
        )
        for stream in response["logStreams"]:
            client.delete_log_stream(
                logGroupName=os.environ['CW_LOG_GROUP_NAME'],
                logStreamName=stream["logStreamName"]
            )
    else:
        # Delete associated s3 bucket objects
        s3 = session.resource('s3')
        bucket = s3.Bucket(os.environ['S3_BUCKET_NAME'])
        s3_objects = bucket.objects.filter(Prefix=f'{OUTPUT_PLUGIN}-test/{PLATFORM}/')
        s3_objects.delete()

def generate_daemonset_config(throughput):
    daemonset_config_dict = {
        '$THROUGHPUT': throughput,
        '$FLUENT_BIT_IMAGE': os.environ['FLUENT_BIT_IMAGE'],
        '$APP_IMAGE': os.environ['EKS_APP_IMAGE'],
        '$TIME': str(LOGGER_RUN_TIME_IN_SECOND),
        '$CW_LOG_GROUP_NAME': os.environ['CW_LOG_GROUP_NAME'],
    }
    fin = open(f'./load_tests/daemonset/{OUTPUT_PLUGIN}.yaml', 'r')
    data = fin.read()
    for key in daemonset_config_dict:
        data = data.replace(key, daemonset_config_dict[key])  
    fout = open(f'./load_tests/daemonset/{OUTPUT_PLUGIN}_{throughput}.yaml', 'w')
    fout.write(data)
    fout.close()
    fin.close()

def run_eks_tests():
    client = boto3.client('logs')
    processes = set()

    for throughput in THROUGHPUT_LIST:
        generate_daemonset_config(throughput)
        os.system(f'kubectl apply -f ./load_tests/daemonset/{OUTPUT_PLUGIN}_{throughput}.yaml')
    # wait (10 mins run + buffer for setup/log delivery)
    time.sleep(1000)
    for throughput in THROUGHPUT_LIST:
        input_record = calculate_total_input_number(throughput)
        response = client.describe_log_streams(
            logGroupName=os.environ['CW_LOG_GROUP_NAME'],
            logStreamNamePrefix=f'{PREFIX}kube.var.log.containers.ds-cloudwatch-{throughput}',
            orderBy='LogStreamName'
        ) 
        for log_stream in response['logStreams']:
            if 'app-' not in log_stream['logStreamName']:
                continue
            expect_time = log_stream['lastEventTimestamp']
            actual_time = log_stream['lastIngestionTime']
            log_delay = get_log_delay(actual_time/1000-expect_time/1000)
            os.environ['LOG_PREFIX'] = log_stream['logStreamName']
            os.environ['DESTINATION'] = 'cloudwatch'
            processes.add(subprocess.Popen(['go', 'run', './load_tests/validation/validate.go', input_record, log_delay]))
    
    # Wait until all subprocesses for validation completed
    for p in processes:
        p.wait()

def delete_testing_resources():
    # Create sts session
    session = get_sts_boto_session()

    # All related testing resources will be destroyed once the stack is deleted 
    client = session.client('cloudformation')
    client.delete_stack(
        StackName=TESTING_RESOURCES_STACK_NAME
    )
    # Empty s3 bucket
    s3 = session.resource('s3')
    bucket = s3.Bucket(os.environ['S3_BUCKET_NAME'])
    bucket.objects.all().delete()
    # scale down eks cluster
    if PLATFORM == 'eks':
        os.system('kubectl delete namespace load-test-fluent-bit-eks-ns')
        os.system(f'eksctl scale nodegroup --cluster={EKS_CLUSTER_NAME} --nodes=0 ng')

def get_validated_input_prefix(input_logger):
    # Prefix used to form destination identifier
    # [log source] ----- (stdout) -> std-{{throughput}}/...
    #               \___ (tcp   ) -> {{throughput}}/...
    #
    # All inputs should have throughput as destination identifier
    # except stdstream
    if (input_logger['name'] == 'stdstream'):
        return resource_resolver.STD_INPUT_PREFIX
    return resource_resolver.CUSTOM_INPUT_PREFIX

def get_sts_boto_session():
    # STS credentials
    sts_client = boto3.client('sts')

    # Call the assume_role method of the STSConnection object and pass the role
    # ARN and a role session name.
    assumed_role_object = sts_client.assume_role(
        RoleArn=os.environ["LOAD_TEST_CFN_ROLE_ARN"],
        RoleSessionName="load-test-cfn"
    )

    # From the response that contains the assumed role, get the temporary 
    # credentials that can be used to make subsequent API calls
    credentials=assumed_role_object['Credentials']

    # Create boto session
    return boto3.Session(
        aws_access_key_id=credentials['AccessKeyId'],
        aws_secret_access_key=credentials['SecretAccessKey'],
        aws_session_token=credentials['SessionToken']
    )

if sys.argv[1] == 'create_testing_resources':
    create_testing_resources()
elif sys.argv[1] == 'ECS':
    run_ecs_tests()
elif sys.argv[1] == 'EKS':
    run_eks_tests()
elif sys.argv[1] == 'delete_testing_resources':
    # testing resources only need to be deleted once
    if OUTPUT_PLUGIN == 'cloudwatch':
        delete_testing_resources()
