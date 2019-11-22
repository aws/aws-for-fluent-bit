#!/bin/bash
export AWS_REGION="us-west-2"
export PROJECT_ROOT="$(pwd)"

test_cloudwatch() {
	export LOG_GROUP_NAME="fluent-bit-integ-test"
	# Tag is used to name the log stream; each test run has a unique (random) log stream name
	export TAG=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
	docker-compose --file ./integ/test_cloudwatch/docker-compose.test.yml build
	docker-compose --file ./integ/test_cloudwatch/docker-compose.test.yml up --abort-on-container-exit
	sleep 10
	# Validate that log data is present in CW
	docker-compose --file ./integ/test_cloudwatch/docker-compose.validate.yml build
	docker-compose --file ./integ/test_cloudwatch/docker-compose.validate.yml up --abort-on-container-exit
}

clean_cloudwatch() {
	export LOG_GROUP_NAME="fluent-bit-integ-test"
	# Clean up resources that were created in the test
	docker-compose --file ./integ/test_cloudwatch/docker-compose.clean.yml build
	docker-compose --file ./integ/test_cloudwatch/docker-compose.clean.yml up --abort-on-container-exit
}

validate_or_clean_s3() {
	# Validate: validates that appropirate log data is present in the s3 bucket
	# Clean: deletes all the objects from s3 bucket that were created in the test
	export S3_ACTION="${1}"
	docker-compose --file ./integ/test_kinesis/docker-compose.validate-and-clean-s3.yml build
	docker-compose --file ./integ/test_kinesis/docker-compose.validate-and-clean-s3.yml up --abort-on-container-exit
}

test_kinesis() {
	# Generates log data which will be stored on the s3 bucket
	docker-compose --file ./integ/test_kinesis/docker-compose.test.yml build
	docker-compose --file ./integ/test_kinesis/docker-compose.test.yml up --abort-on-container-exit

    # Giving a pause before running the validation test
    # Firehose delivery stream has a buffer time which causes the delay to send the data
	sleep 120

	# Creates a file as a flag for the validation failure
	mkdir -p ./integ/out
	touch ./integ/out/kinesis-test

	validate_or_clean_s3 validate

	if [ -f ./integ/out/kinesis-test ]; then
		# if the file still exists, test failed
		echo "Test failed for kinesis stream."
		exit 1
	fi
}

clean_s3() {
	validate_or_clean_s3 clean
}

if [ "${1}" = "cloudwatch" ]; then
	mkdir -p ./integ/out
	touch ./integ/out/cloudwatch-test
	test_cloudwatch
	clean_cloudwatch
	if [ -f ./integ/out/cloudwatch-test ]; then
		# if the file still exists, test failed
		echo "Test Failed."
		exit 1
	fi
fi

if [ "${1}" = "clean-cloudwatch" ]; then
	clean_cloudwatch
fi

if [ "${1}" = "kinesis" ]; then
	source ./integ/resources/create_test_resources.sh
	source ./integ/resources/setup_test_environment.sh

	clean_s3 && test_kinesis
fi

if [ "${1}" = "clean-s3" ]; then
	source ./integ/resources/setup_test_environment.sh
	clean_s3
fi

if [ "${1}" = "cicd" ]; then
	source ./integ/resources/setup_test_environment.sh
    test_cloudwatch && clean_cloudwatch
	clean_s3 && test_kinesis
fi

if [ "${1}" = "delete" ]; then
	source ./integ/resources/delete_test_resources.sh
fi
