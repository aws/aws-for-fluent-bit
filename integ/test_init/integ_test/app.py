#!/usr/bin/env python3
import os

import aws_cdk as cdk

from integ_test.integ_test_stack import IntegTestStack


app = cdk.App()
IntegTestStack(app, "IntegTestStack",
    # If you don't specify 'env', this stack will be environment-agnostic.
    # Account/Region-dependent features and context lookups will not work,
    # but a single synthesized template can be deployed anywhere.

    # Uncomment the next line to specialize this stack for the AWS Account
    # and Region that are implied by the current CLI configuration.

    #env=cdk.Environment(account=os.getenv('CDK_DEFAULT_ACCOUNT'), region=os.getenv('CDK_DEFAULT_REGION')),

    # Uncomment the next line and fill in account and region if you know exactly 
    # what Account and Region you want to deploy the stack to.
    # https://docs.aws.amazon.com/cdk/api/v2/python/aws_cdk/Environment.html

    #env=cdk.Environment(account='', region='us-east-1'),

    # For more information, see https://docs.aws.amazon.com/cdk/latest/guide/environments.html
    )

app.synth()
