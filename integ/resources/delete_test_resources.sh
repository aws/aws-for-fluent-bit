# Delete the CloudFormation stack which created all the resources for running the integration test
ARCHITECTURE=$(uname -m)
if [ ARCHITECTURE=="x86_64" ] 
then
    ARCHITECTURE="x86-64"
fi
aws cloudformation delete-stack --stack-name integ-test-fluent-bit-${ARCHITECTURE}