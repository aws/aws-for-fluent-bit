import aws_cdk as core
import aws_cdk.assertions as assertions

from integ_test.integ_test_stack import IntegTestStack

# example tests. To run these tests, uncomment this file along with the example
# resource in integ_test/integ_test_stack.py
def test_sqs_queue_created():
    app = core.App()
    stack = IntegTestStack(app, "integ-test")
    template = assertions.Template.from_stack(stack)

#     template.has_resource_properties("AWS::SQS::Queue", {
#         "VisibilityTimeout": 300
#     })
