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

# Execute set-cache to turn docker cache back on for faster development.
DOCKER_BUILD_FLAGS :=

.PHONY: dev
dev: DOCKER_BUILD_FLAGS =
dev: release

.PHONY: release
release: build build-init linux-plugins
	docker system prune -f
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:main-release -f ./scripts/dockerfiles/Dockerfile.main-release .
	docker tag amazon/aws-for-fluent-bit:main-release amazon/aws-for-fluent-bit:latest
	docker system prune -f
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:init-latest -f ./scripts/dockerfiles/Dockerfile.init-release .

.PHONY: debug
debug: main-debug init-debug

.PHONY: build
build:
	docker system prune -f
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:build -f ./scripts/dockerfiles/Dockerfile.build .

.PHONY: build-init
build-init:
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:build-init -f ./scripts/dockerfiles/Dockerfile.build-init .

#TODO: the bash script opts does not work on developer Macs
windows-plugins: export OS_TYPE = windows
linux-plugins: export OS_TYPE = linux

.PHONY: windows-plugins
windows-plugins:
	./scripts/build_plugins.sh \
    	--KINESIS_PLUGIN_CLONE_URL=${KINESIS_PLUGIN_CLONE_URL} \
    	--KINESIS_PLUGIN_TAG=${KINESIS_PLUGIN_TAG} \
    	--KINESIS_PLUGIN_BRANCH=${KINESIS_PLUGIN_BRANCH} \
    	--FIREHOSE_PLUGIN_CLONE_URL=${FIREHOSE_PLUGIN_CLONE_URL} \
    	--FIREHOSE_PLUGIN_TAG=${FIREHOSE_PLUGIN_TAG} \
    	--FIREHOSE_PLUGIN_BRANCH=${FIREHOSE_PLUGIN_BRANCH} \
    	--CLOUDWATCH_PLUGIN_CLONE_URL=${CLOUDWATCH_PLUGIN_CLONE_URL} \
    	--CLOUDWATCH_PLUGIN_TAG=${CLOUDWATCH_PLUGIN_TAG} \
    	--CLOUDWATCH_PLUGIN_BRANCH=${CLOUDWATCH_PLUGIN_BRANCH} \
    	--DOCKER_BUILD_FLAGS=${DOCKER_BUILD_FLAGS}

.PHONY: linux-plugins
linux-plugins:
	./scripts/build_plugins.sh \
    	--KINESIS_PLUGIN_CLONE_URL=${KINESIS_PLUGIN_CLONE_URL} \
    	--KINESIS_PLUGIN_TAG=${KINESIS_PLUGIN_TAG} \
    	--KINESIS_PLUGIN_BRANCH=${KINESIS_PLUGIN_BRANCH} \
    	--FIREHOSE_PLUGIN_CLONE_URL=${FIREHOSE_PLUGIN_CLONE_URL} \
    	--FIREHOSE_PLUGIN_TAG=${FIREHOSE_PLUGIN_TAG} \
    	--FIREHOSE_PLUGIN_BRANCH=${FIREHOSE_PLUGIN_BRANCH} \
    	--CLOUDWATCH_PLUGIN_CLONE_URL=${CLOUDWATCH_PLUGIN_CLONE_URL} \
    	--CLOUDWATCH_PLUGIN_TAG=${CLOUDWATCH_PLUGIN_TAG} \
    	--CLOUDWATCH_PLUGIN_BRANCH=${CLOUDWATCH_PLUGIN_BRANCH} \
    	--DOCKER_BUILD_FLAGS=${DOCKER_BUILD_FLAGS}

# Debug and debug init images
.PHONY: main-debug
main-debug: debug-s3
	docker tag amazon/aws-for-fluent-bit:debug-s3 amazon/aws-for-fluent-bit:debug

.PHONY: init-debug
init-debug: init-debug-s3
	docker tag amazon/aws-for-fluent-bit:init-debug-s3 amazon/aws-for-fluent-bit:init-debug

# Build all main debug images (Don't build the dependencies multiple times)
.PHONY: main-debug-all
main-debug-all: main-debug-base
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:debug-fs       -f ./scripts/dockerfiles/Dockerfile.main-debug-fs .
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:debug-s3       -f ./scripts/dockerfiles/Dockerfile.main-debug-s3 .
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:debug-valgrind -f ./scripts/dockerfiles/Dockerfile.main-debug-valgrind .
	docker tag amazon/aws-for-fluent-bit:debug-s3 amazon/aws-for-fluent-bit:debug

# Debug images
.PHONY: debug-fs
debug-fs: main-debug-base
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:debug-fs       -f ./scripts/dockerfiles/Dockerfile.main-debug-fs .

.PHONY: debug-s3
debug-s3: main-debug-base
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:debug-s3       -f ./scripts/dockerfiles/Dockerfile.main-debug-s3 .

.PHONY: debug-valgrind
debug-valgrind: main-debug-base
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:debug-valgrind -f ./scripts/dockerfiles/Dockerfile.main-debug-valgrind .

# Build all init debug images (Don't build the dependencies multiple times)
.PHONY: init-debug-all
init-debug-all: main-debug-base build-init
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:init-debug-base -f ./scripts/dockerfiles/Dockerfile.init-debug-base .
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:init-debug-fs   -f ./scripts/dockerfiles/Dockerfile.init-debug-fs .
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:init-debug-s3   -f ./scripts/dockerfiles/Dockerfile.init-debug-s3 .
	docker tag amazon/aws-for-fluent-bit:init-debug-s3 amazon/aws-for-fluent-bit:init-debug

# Debug init images
.PHONY: init-debug-fs
init-debug-fs: main-debug-base build-init
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:init-debug-base -f ./scripts/dockerfiles/Dockerfile.init-debug-base .
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:init-debug-fs   -f ./scripts/dockerfiles/Dockerfile.init-debug-fs .

.PHONY: init-debug-s3
init-debug-s3: main-debug-base build-init
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:init-debug-base -f ./scripts/dockerfiles/Dockerfile.init-debug-base .
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:init-debug-s3   -f ./scripts/dockerfiles/Dockerfile.init-debug-s3 .

.PHONY: main-debug-base
main-debug-base: build linux-plugins
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:main-debug-base  -f ./scripts/dockerfiles/Dockerfile.main-debug-base .

.PHONY: validate-version-file-format
validate-version-file-format:
	jq -e . windows.versions && true || false
	jq -e . linux.version && true || false

.PHONY: cloudwatch-dev
cloudwatch-dev:
	docker build \
	--build-arg CLOUDWATCH_PLUGIN_CLONE_URL=${CLOUDWATCH_PLUGIN_CLONE_URL} \
	--build-arg CLOUDWATCH_PLUGIN_BRANCH=${CLOUDWATCH_PLUGIN_BRANCH} \
	$(DOCKER_BUILD_FLAGS) -t aws-fluent-bit-plugins:latest -f ./scripts/dockerfiles/Dockerfile.plugins .
	docker build -t amazon/aws-for-fluent-bit:latest -f ./scripts/dockerfiles/Dockerfile .

.PHONY: firehose-dev
firehose-dev:
	docker build \
	--build-arg FIREHOSE_PLUGIN_CLONE_URL=${FIREHOSE_PLUGIN_CLONE_URL} \
	--build-arg FIREHOSE_PLUGIN_BRANCH=${FIREHOSE_PLUGIN_BRANCH} \
	$(DOCKER_BUILD_FLAGS) -t aws-fluent-bit-plugins:latest -f ./scripts/dockerfiles/Dockerfile.plugins .
	docker build -t amazon/aws-for-fluent-bit:latest -f ./scripts/dockerfiles/Dockerfile .

.PHONY: kinesis-dev
kinesis-dev:
	docker build \
	--build-arg KINESIS_PLUGIN_CLONE_URL=${KINESIS_PLUGIN_CLONE_URL} \
	--build-arg KINESIS_PLUGIN_BRANCH=${KINESIS_PLUGIN_BRANCH} \
	$(DOCKER_BUILD_FLAGS) -t aws-fluent-bit-plugins:latest -f ./scripts/dockerfiles/Dockerfile.plugins .
	docker build -t amazon/aws-for-fluent-bit:latest -f ./scripts/dockerfiles/Dockerfile .

integ/out:
	mkdir -p integ/out

.PHONY: integ-cloudwatch
integ-cloudwatch: integ/out release
	./integ/integ.sh cloudwatch

.PHONY: integ-cloudwatch-dev
integ-cloudwatch-dev: integ/out cloudwatch-dev
	./integ/integ.sh cloudwatch

.PHONY: integ-clean-cloudwatch
integ-clean-cloudwatch: integ/out
	./integ/integ.sh clean-cloudwatch

.PHONY: integ-kinesis
integ-kinesis: integ/out release
	./integ/integ.sh kinesis

.PHONY: integ-kinesis-dev
integ-kinesis-dev: integ/out kinesis-dev
	./integ/integ.sh kinesis

.PHONY: integ-firehose
integ-firehose: integ/out release
	./integ/integ.sh firehose

.PHONY: integ-firehose-dev
integ-firehose-dev: integ/out firehose-dev
	./integ/integ.sh firehose

.PHONY: integ-clean-s3
integ-clean-s3: integ/out
	./integ/integ.sh clean-s3

.PHONY: integ-dev
integ-dev: integ/out dev
	./integ/integ.sh kinesis
	./integ/integ.sh kinesis_streams
	./integ/integ.sh firehose
	./integ/integ.sh kinesis_firehose
	./integ/integ.sh cloudwatch
	./integ/integ.sh cloudwatch_logs

.PHONY: integ
integ: integ/out
	./integ/integ.sh cicd

.PHONY: delete-resources
delete-resources:
	./integ/integ.sh delete

.PHONY: clean
clean:
	rm -rf ./build
	rm -rf ./integ/out
	docker image remove -f aws-fluent-bit-plugins:latest

	docker image remove -f amazon/aws-for-fluent-bit:latest
	docker image remove -f amazon/aws-for-fluent-bit:init-latest
	docker image remove -f amazon/aws-for-fluent-bit:debug
	docker image remove -f amazon/aws-for-fluent-bit:init-debug

	docker image remove -f amazon/aws-for-fluent-bit:build
	docker image remove -f amazon/aws-for-fluent-bit:build-init
	docker image remove -f amazon/aws-for-fluent-bit:init-debug-base
	docker image remove -f amazon/aws-for-fluent-bit:main-debug-base

	docker image remove -f amazon/aws-for-fluent-bit:init-release
	docker image remove -f amazon/aws-for-fluent-bit:main-release
	docker image remove -f amazon/aws-for-fluent-bit:debug-fs
	docker image remove -f amazon/aws-for-fluent-bit:debug-s3
	docker image remove -f amazon/aws-for-fluent-bit:debug-valgrind
	docker image remove -f amazon/aws-for-fluent-bit:init-debug-fs
	docker image remove -f amazon/aws-for-fluent-bit:init-debug-s3

	docker image prune -f
