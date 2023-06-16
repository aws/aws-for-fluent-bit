#!/bin/bash
export AWS_REGION="us-west-2"
export PROJECT_ROOT="$(pwd)"
export VOLUME_MOUNT_CONTAINER="/out"

test_cloudwatch() {
	export ARCHITECTURE=$(uname -m)
	export LOG_GROUP_NAME="fluent-bit-integ-test-${ARCHITECTURE}"
	# Tag is used to name the log stream; each test run has a unique (random) log stream name
	export TAG=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
	docker-compose --file ./integ/test_cloudwatch/docker-compose.test.yml build
	docker-compose --file ./integ/test_cloudwatch/docker-compose.test.yml up --abort-on-container-exit
	sleep 120

	# Creates a file as a flag for the validation failure
	mkdir -p ./integ/out
	touch ./integ/out/cloudwatch-test

	# Validate that log data is present in CW
	docker-compose --file ./integ/test_cloudwatch/docker-compose.validate.yml build
	docker-compose --file ./integ/test_cloudwatch/docker-compose.validate.yml up --abort-on-container-exit
}

clean_cloudwatch() {
	export LOG_GROUP_NAME="fluent-bit-integ-test-${ARCHITECTURE}"
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

test_kinesis_streams() {
	# Generates log data which will be stored on the s3 bucket
	docker-compose --file ./integ/test_kinesis/docker-compose.core.test.yml build
	docker-compose --file ./integ/test_kinesis/docker-compose.core.test.yml up --abort-on-container-exit

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

test_firehose() {
	# Generates log data which will be stored on the s3 bucket
	docker-compose --file ./integ/test_firehose/docker-compose.test.yml build
	docker-compose --file ./integ/test_firehose/docker-compose.test.yml up --abort-on-container-exit

    # Giving a pause before running the validation test
    # Firehose delivery stream has a buffer time which causes the delay to send the data
	sleep 120

	# Creates a file as a flag for the validation failure
	mkdir -p ./integ/out
	touch ./integ/out/firehose-test

	validate_or_clean_s3 validate

	if [ -f ./integ/out/firehose-test ]; then
		# if the file still exists, test failed
		echo "Test failed for firehose."
		exit 1
	fi
}

test_kinesis_firehose() {
	# Generates log data which will be stored on the s3 bucket
	docker-compose --file ./integ/test_firehose/docker-compose.core.test.yml build
	docker-compose --file ./integ/test_firehose/docker-compose.core.test.yml up --abort-on-container-exit

    # Giving a pause before running the validation test
    # Firehose delivery stream has a buffer time which causes the delay to send the data
	sleep 120

	# Creates a file as a flag for the validation failure
	mkdir -p ./integ/out
	touch ./integ/out/firehose-test

	validate_or_clean_s3 validate

	if [ -f ./integ/out/firehose-test ]; then
		# if the file still exists, test failed
		echo "Test failed for firehose."
		exit 1
	fi
}

test_s3() {
	# different S3 prefix for each test
	export ARCHITECTURE=$(uname -m)
	export S3_PREFIX_PUT_OBJECT="logs/${ARCHITECTURE}/putobject"
	export S3_PREFIX_MULTIPART="logs/${ARCHITECTURE}/multipart"
	# Tag is used in the s3 keys; each test run has a unique (random) tag
	export TAG=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
	# Generates log data which will be stored on the s3 bucket
	docker-compose --file ./integ/test_s3/docker-compose.test.yml build
	docker-compose --file ./integ/test_s3/docker-compose.test.yml up --abort-on-container-exit

    # Giving a pause before running the validation test
	sleep 20

	# Creates a file as a flag for the validation failure
	mkdir -p ./integ/out
	touch ./integ/out/s3-test

	export S3_ACTION="validate"
	docker-compose --file ./integ/test_s3/docker-compose.validate-s3-multipart.yml build
	docker-compose --file ./integ/test_s3/docker-compose.validate-s3-multipart.yml up --abort-on-container-exit

	if [ -f ./integ/out/s3-test ]; then
		# if the file still exists, test failed
		echo "Test failed for S3."
		exit 1
	fi

	# Creates a file as a flag for the validation failure
	mkdir -p ./integ/out
	touch ./integ/out/s3-test

	export S3_ACTION="validate"
	docker-compose --file ./integ/test_s3/docker-compose.validate-s3-putobject.yml build
	docker-compose --file ./integ/test_s3/docker-compose.validate-s3-putobject.yml up --abort-on-container-exit

	if [ -f ./integ/out/s3-test ]; then
		# if the file still exists, test failed
		echo "Test failed for S3."
		exit 1
	fi
}


clean_s3() {
	validate_or_clean_s3 clean
}
if [ "${1}" = "cloudwatch" ]; then
	export CW_PLUGIN_UNDER_TEST="cloudwatch"
	test_cloudwatch
	clean_cloudwatch

	if [ -f ./integ/out/cloudwatch-test ]; then
		# if the file still exists, test failed
		echo "Test Failed for Cloudwatch."
		exit 1
	fi
fi

if [ "${1}" = "cloudwatch_logs" ]; then
	export CW_PLUGIN_UNDER_TEST="cloudwatch_logs"
	test_cloudwatch
	clean_cloudwatch

	if [ -f ./integ/out/cloudwatch-test ]; then
		# if the file still exists, test failed
		echo "Test Failed for Cloudwatch."
		exit 1
	fi
fi

if [ "${1}" = "clean-cloudwatch" ]; then
	clean_cloudwatch
fi

if [ "${1}" = "kinesis" ]; then
	export S3_PREFIX="kinesis-test"
	export TEST_FILE="kinesis-test"
	export EXPECTED_EVENTS_LEN="1000"
	source ./integ/resources/create_test_resources.sh
	source ./integ/resources/setup_test_environment.sh

	clean_s3 && test_kinesis
fi

if [ "${1}" = "kinesis_streams" ]; then
	export S3_PREFIX="kinesis-test"
	export TEST_FILE="kinesis-test"
	export EXPECTED_EVENTS_LEN="1000"
	source ./integ/resources/create_test_resources.sh
	source ./integ/resources/setup_test_environment.sh

	clean_s3 && test_kinesis_streams
fi

if [ "${1}" = "firehose" ]; then
	export S3_PREFIX="firehose-test"
	export TEST_FILE="firehose-test"
	export EXPECTED_EVENTS_LEN="1000"
	source ./integ/resources/create_test_resources.sh
	source ./integ/resources/setup_test_environment.sh

	clean_s3 && test_firehose
fi

if [ "${1}" = "kinesis_firehose" ]; then
	export S3_PREFIX="firehose-test"
	export TEST_FILE="firehose-test"
	export EXPECTED_EVENTS_LEN="1000"
	source ./integ/resources/create_test_resources.sh
	source ./integ/resources/setup_test_environment.sh

	clean_s3 && test_kinesis_firehose
fi

if [ "${1}" = "s3" ]; then
	export S3_PREFIX="logs"
	export TEST_FILE="s3-test"
	export EXPECTED_EVENTS_LEN="7717"
	source ./integ/resources/create_test_resources.sh
	source ./integ/resources/setup_test_environment.sh

	clean_s3 && test_s3
fi

if [ "${1}" = "clean-s3" ]; then
	source ./integ/resources/setup_test_environment.sh
	clean_s3
fi

if [ "${1}" = "cicd" ]; then
	export CW_PLUGIN_UNDER_TEST="cloudwatch"
	echo "Running tests on Golang CW Plugin"
	test_cloudwatch && clean_cloudwatch
	if [ -f ./integ/out/cloudwatch-test ]; then
		# if the file still exists, test failed
		echo "Test Failed for Cloudwatch (Golang)."
		exit 1
	fi

	export CW_PLUGIN_UNDER_TEST="cloudwatch_logs"
	echo "Running tests on Core C CW Plugin"
	test_cloudwatch && clean_cloudwatch
	if [ -f ./integ/out/cloudwatch-test ]; then
		# if the file still exists, test failed
		echo "Test Failed for Cloudwatch (Core)."
		exit 1
	fi

	source ./integ/resources/setup_test_environment.sh

	# golang kinesis plugin
	export S3_PREFIX="kinesis-test"
	export TEST_FILE="kinesis-test"
	export EXPECTED_EVENTS_LEN="1000"
	clean_s3 && test_kinesis
	
	# golang firehose plugin
	export S3_PREFIX="firehose-test"
	export TEST_FILE="firehose-test"
	clean_s3 && test_firehose

	# core kinesis plugin
	export S3_PREFIX="kinesis-test"
	export TEST_FILE="kinesis-test"
	export EXPECTED_EVENTS_LEN="1000"
	clean_s3 && test_kinesis_streams

	# core firehose plugin
	export S3_PREFIX="firehose-test"
	export TEST_FILE="firehose-test"
	clean_s3 && test_kinesis_firehose

	export S3_PREFIX="logs"
	export TEST_FILE="s3-test"
	export EXPECTED_EVENTS_LEN="7717"
	source ./integ/resources/create_test_resources.sh
	source ./integ/resources/setup_test_environment.sh

	clean_s3 && test_s3
fi

if [ "${1}" = "delete" ]; then
	source ./integ/resources/delete_test_resources.sh
fi