import os
from aws_cdk import (
    aws_logs as logs,
    Stack,
    App,
    CfnOutput,
    RemovalPolicy
)
from constructs import Construct

# Create necessary EKS load testing resources - cloudwatch log group
class TestingResources(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        log_group = logs.LogGroup(self, 'logGroup',
                                  removal_policy=RemovalPolicy.DESTROY)

        # Add stack outputs
        CfnOutput(self, 'CloudWatchLogGroupName', 
                       value=log_group.log_group_name, 
                       description='CloudWatch Log Group Name')

app = App()
TestingResources(app, os.environ['TESTING_RESOURCES_STACK_NAME'])
app.synth()
