import json
import os

PREFIX = os.environ['PREFIX']
BUILD_VERSION = os.environ.get('BUILD_VERSION', '2')
VERSION_SUFFIX = '' if BUILD_VERSION == '2' else f'-v{BUILD_VERSION}'
CUSTOM_INPUT_PREFIX = "" # "" is the destination tag for logs coming from non-stdstream input
STD_INPUT_PREFIX = "std-"

INPUT_PREFIX_LIST = [CUSTOM_INPUT_PREFIX, STD_INPUT_PREFIX]
THROUGHPUT_LIST = json.loads(os.environ['THROUGHPUT_LIST'])
PLATFORM_LIST = [ os.environ['PLATFORM'].lower() ]

def get_input_configuration(platform, input_prefix, throughput):
    return {
        "platform": platform.lower(),
        "input_prefix": input_prefix.lower(),
        "throughput": throughput.lower(),
    }

# Destination identifier is used in LOG_PREFIX
def get_destination_cloudwatch_prefix(input_configuration):
    return f'{input_configuration["input_prefix"]}{input_configuration["throughput"]}'

def get_destination_s3_prefix(input_configuration, output_plugin):
    return f'{output_plugin}-test/{input_configuration["platform"]}/{input_configuration["input_prefix"]}{input_configuration["throughput"]}/'

def resolve_firehose_delivery_stream_name(input_configuration):
    return f'{PREFIX}{input_configuration["platform"]}-firehoseTest-deliveryStream-{input_configuration["input_prefix"]}{input_configuration["throughput"]}{VERSION_SUFFIX}'

def resolve_kinesis_stream_name(input_configuration):
    return f'{PREFIX}{input_configuration["platform"]}-kinesisStream-{input_configuration["input_prefix"]}{input_configuration["throughput"]}{VERSION_SUFFIX}'

def resolve_s3_object_name(input_configuration):
    return f'/s3-test/{input_configuration["platform"]}/{input_configuration["input_prefix"]}{input_configuration["throughput"]}/$TAG/%Y/%m/%d/%H/%M/%S'

def resolve_cloudwatch_logs_stream_name(input_configuration):
    return f'{input_configuration["input_prefix"]}{input_configuration["throughput"]}'
