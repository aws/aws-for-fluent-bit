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
	# Clean up resources that were created in the test
	docker-compose --file ./integ/test_cloudwatch/docker-compose.clean.yml build
	docker-compose --file ./integ/test_cloudwatch/docker-compose.clean.yml up --abort-on-container-exit
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

if [ "${1}" = "clean" ]; then
	clean_cloudwatch
fi
