import boto3
import json
import sys
import os

"""
This script deletes any resources created in the fluent bit integ tests
"""

LOG_GROUP_NAME = os.environ.get('LOG_GROUP_NAME')

client = boto3.client('logs', region_name=os.environ.get('AWS_REGION'))

print('deleting log group: ' + LOG_GROUP_NAME)
client.delete_log_group(logGroupName=LOG_GROUP_NAME)
