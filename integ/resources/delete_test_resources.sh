# Delete the CloudFormation stack which created all the resources for running the integration test
ARCHITECTURE=$(uname -m | tr '_' '-')
# For arm, uname evaluates to 'aarch64' but everywhere else in the pipline
# we use 'arm64'
if [ "$ARCHITECTURE" = "aarch64" ]; then
    ARCHITECTURE="arm64"
fi
aws cloudformation delete-stack --stack-name integ-test-fluent-bit-${ARCHITECTURE}