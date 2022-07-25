# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
# 	http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.

all: release

.PHONY: release
release:
	docker build --no-cache -t aws-fluent-bit-plugins:latest -f Dockerfile.plugins .
	docker build -t amazon/aws-for-fluent-bit:latest -f Dockerfile .
	docker build -t amazon/aws-for-fluent-bit:init-latest -f Dockerfile.init .

.PHONY: debug
debug:
	docker build --no-cache -t aws-fluent-bit-plugins:latest -f Dockerfile.plugins .
	docker build --no-cache -t amazon/aws-for-fluent-bit:debug -f Dockerfile.debug .

.PHONY: cloudwatch-dev
cloudwatch-dev:
	docker build \
	--build-arg CLOUDWATCH_PLUGIN_CLONE_URL=${CLOUDWATCH_PLUGIN_CLONE_URL} \
	--build-arg CLOUDWATCH_PLUGIN_BRANCH=${CLOUDWATCH_PLUGIN_BRANCH} \
	--no-cache -t aws-fluent-bit-plugins:latest -f Dockerfile.plugins .
	docker build -t amazon/aws-for-fluent-bit:latest -f Dockerfile .

.PHONY: firehose-dev
firehose-dev:
	docker build \
	--build-arg FIREHOSE_PLUGIN_CLONE_URL=${FIREHOSE_PLUGIN_CLONE_URL} \
	--build-arg FIREHOSE_PLUGIN_BRANCH=${FIREHOSE_PLUGIN_BRANCH} \
	--no-cache -t aws-fluent-bit-plugins:latest -f Dockerfile.plugins .
	docker build -t amazon/aws-for-fluent-bit:latest -f Dockerfile .

.PHONY: kinesis-dev
kinesis-dev:
	docker build \
	--build-arg KINESIS_PLUGIN_CLONE_URL=${KINESIS_PLUGIN_CLONE_URL} \
	--build-arg KINESIS_PLUGIN_BRANCH=${KINESIS_PLUGIN_BRANCH} \
	--no-cache -t aws-fluent-bit-plugins:latest -f Dockerfile.plugins .
	docker build -t amazon/aws-for-fluent-bit:latest -f Dockerfile .

.PHONY: integ-cloudwatch
integ-cloudwatch: release
	./integ/integ.sh cloudwatch

.PHONY: integ-cloudwatch-dev
integ-cloudwatch-dev: cloudwatch-dev
	./integ/integ.sh cloudwatch

.PHONY: integ-clean-cloudwatch
integ-clean-cloudwatch:
	./integ/integ.sh clean-cloudwatch

.PHONY: integ-kinesis
integ-kinesis: release
	./integ/integ.sh kinesis

.PHONY: integ-kinesis-dev
integ-kinesis-dev: kinesis-dev
	./integ/integ.sh kinesis

.PHONY: integ-firehose
integ-firehose: release
	./integ/integ.sh firehose

.PHONY: integ-firehose-dev
integ-firehose-dev: firehose-dev
	./integ/integ.sh firehose

.PHONY: integ-clean-s3
integ-clean-s3:
	./integ/integ.sh clean-s3

.PHONY: integ-dev
integ-dev: release
	./integ/integ.sh kinesis
	./integ/integ.sh kinesis_streams
	./integ/integ.sh firehose
	./integ/integ.sh kinesis_firehose
	./integ/integ.sh cloudwatch
	./integ/integ.sh cloudwatch_logs

.PHONY: integ
integ:
	./integ/integ.sh cicd

.PHONY: delete-resources
delete-resources:
	./integ/integ.sh delete
