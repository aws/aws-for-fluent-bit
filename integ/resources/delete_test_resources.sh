# Delete the CloudFormation stack which created all the resources for running the integration test
ARCHITECTURE=$(uname -m | tr '_' '-')
aws cloudformation delete-stack --stack-name integ-test-fluent-bit-${ARCHITECTURE}