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
DOCKER_BUILD_FLAGS := "--no-cache"
# Build Version
BUILD_VERSION ?= 3
# Amazon Linux Tag to use for images, derived from linux.version if not set
AL_TAG ?= $(shell ./scripts/get_linux_version.sh ${BUILD_VERSION} al-tag)
# Fluent Bit version (branch or tag) to checkout, derived from linux.version if not set
FLB_VERSION ?= $(shell ./scripts/get_linux_version.sh ${BUILD_VERSION} fluent-bit)
# Fluent Bit repository to checkout, derived from linux.version if not set
FLB_REPOSITORY ?= $(shell ./scripts/get_linux_version.sh ${BUILD_VERSION} flb-repository)
# AWS for Fluent Bit Version
AWS_FOR_FLUENT_BIT_VERSION ?= $(shell ./scripts/get_linux_version.sh ${BUILD_VERSION} version)
# sha256 digest for the OS image
OS_DIGEST ?= $(shell ./scripts/get_linux_version.sh ${BUILD_VERSION} os-digest)
# OS Pretty Name
OS_PRETTY_NAME := "$(shell docker run --rm public.ecr.aws/amazonlinux/amazonlinux@${OS_DIGEST} sh -c "grep '^PRETTY_NAME=' /etc/os-release | cut -d'\"' -f2")"
# Alternative OS identifier for container images
OS_IMAGE_ID := "$(shell docker run --rm public.ecr.aws/amazonlinux/amazonlinux@${OS_DIGEST} sh -c "grep '^image_file=' /etc/image-id | cut -d'\"' -f2")"

.PHONY: dev
dev: DOCKER_BUILD_FLAGS =
dev: release

.PHONY: build-common
build-common:
	docker build $(DOCKER_BUILD_FLAGS) --build-arg OS_DIGEST=${OS_DIGEST} -t amazon/aws-for-fluent-bit:build-deps-al${AL_TAG} -f ./scripts/dockerfiles/build/Dockerfile.deps-al${AL_TAG} .
	docker build $(DOCKER_BUILD_FLAGS) --build-arg AL_TAG=${AL_TAG} --build-arg FLB_VERSION=${FLB_VERSION} --build-arg FLB_REPOSITORY=${FLB_REPOSITORY} -t amazon/aws-for-fluent-bit:parsers-al${AL_TAG} -f ./scripts/dockerfiles/build/Dockerfile.parsers-al${AL_TAG} .
	docker build $(DOCKER_BUILD_FLAGS) --build-arg AL_TAG=${AL_TAG} --build-arg FLB_VERSION=${FLB_VERSION} --build-arg FLB_REPOSITORY=${FLB_REPOSITORY} -t amazon/aws-for-fluent-bit:build-common-al${AL_TAG} -f ./scripts/dockerfiles/build/Dockerfile.build-common .
	docker build $(DOCKER_BUILD_FLAGS) --build-arg OS_DIGEST=${OS_DIGEST} -t amazon/aws-for-fluent-bit:golang -f ./scripts/dockerfiles/build/Dockerfile.golang .
	docker build $(DOCKER_BUILD_FLAGS) -t amazon/aws-for-fluent-bit:compile-init-al${AL_TAG} -f ./scripts/dockerfiles/build/Dockerfile.compile-init .

.PHONY: build
build: build-common
	docker build $(DOCKER_BUILD_FLAGS) --build-arg BUILD_IMAGE=amazon/aws-for-fluent-bit:build-common-al${AL_TAG} -t amazon/aws-for-fluent-bit:compile-al${AL_TAG} -f ./scripts/dockerfiles/build/Dockerfile.compile .

.PHONY: build-debug
build-debug: build-common
	# Enable jemalloc heap profiling with libunwind stack unwinding.
	# --with-lg-quantum=3 is required for prof-libunwind on x86_64; -lunwind is passed
	# explicitly because jemalloc's cmake integration does not add it automatically.
	docker build $(DOCKER_BUILD_FLAGS) --build-arg BUILD_IMAGE=amazon/aws-for-fluent-bit:build-common-al${AL_TAG} --build-arg OS_DIGEST=${OS_DIGEST} --build-arg DEBUG=On --build-arg RELEASE=Off --build-arg FLB_JEMALLOC_OPTIONS="--with-lg-quantum=3 --enable-prof --enable-prof-libunwind" --build-arg FLB_EXTRA_LINKER_FLAGS="-lunwind" -t amazon/aws-for-fluent-bit:compile-debug-al${AL_TAG} -f ./scripts/dockerfiles/build/Dockerfile.compile .

.PHONY: windows-plugins
windows-plugins: export OS_TYPE = windows
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
linux-plugins: export OS_TYPE = linux
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

.PHONY: release
release: build linux-plugins
	docker build $(DOCKER_BUILD_FLAGS) --build-arg OS_DIGEST=${OS_DIGEST} -t amazon/aws-for-fluent-bit:runtime-deps-al${AL_TAG} -f ./scripts/dockerfiles/runtime/Dockerfile.deps-al${AL_TAG} .
	docker build $(DOCKER_BUILD_FLAGS) --build-arg COMPILE_IMAGE=amazon/aws-for-fluent-bit:compile-al${AL_TAG} --build-arg RUNTIME_IMAGE=amazon/aws-for-fluent-bit:runtime-deps-al${AL_TAG} --build-arg OS_DIGEST=${OS_DIGEST} --build-arg FLB_VERSION=${FLB_VERSION} --build-arg AWS_FOR_FLUENT_BIT_VERSION=${AWS_FOR_FLUENT_BIT_VERSION} --build-arg OS_PRETTY_NAME=${OS_PRETTY_NAME} --build-arg OS_IMAGE_ID=${OS_IMAGE_ID} --build-arg OS_DIGEST=${OS_DIGEST} -t amazon/aws-for-fluent-bit:latest-al${AL_TAG} -f ./scripts/dockerfiles/runtime/Dockerfile .
	docker build $(DOCKER_BUILD_FLAGS) --build-arg COMPILE_IMAGE=amazon/aws-for-fluent-bit:compile-init-al${AL_TAG} --build-arg RUNTIME_IMAGE=amazon/aws-for-fluent-bit:latest-al${AL_TAG} -t amazon/aws-for-fluent-bit:init-latest-al${AL_TAG} -f ./scripts/dockerfiles/runtime/Dockerfile.init .

.PHONY: debug
debug: build-debug linux-plugins
	docker build $(DOCKER_BUILD_FLAGS) --build-arg OS_DIGEST=${OS_DIGEST} -t amazon/aws-for-fluent-bit:runtime-deps-debug-al${AL_TAG} -f ./scripts/dockerfiles/runtime/Dockerfile.deps-debug-al${AL_TAG} .
	docker build $(DOCKER_BUILD_FLAGS) --build-arg COMPILE_IMAGE=amazon/aws-for-fluent-bit:compile-debug-al${AL_TAG} --build-arg RUNTIME_IMAGE=amazon/aws-for-fluent-bit:runtime-deps-debug-al${AL_TAG} --build-arg FLB_VERSION=${FLB_VERSION} --build-arg AWS_FOR_FLUENT_BIT_VERSION=${AWS_FOR_FLUENT_BIT_VERSION} --build-arg OS_PRETTY_NAME=${OS_PRETTY_NAME} --build-arg OS_IMAGE_ID=${OS_IMAGE_ID} --build-arg OS_DIGEST=${OS_DIGEST} -t amazon/aws-for-fluent-bit:runtime-debug-al${AL_TAG} -f ./scripts/dockerfiles/runtime/Dockerfile .
	docker build $(DOCKER_BUILD_FLAGS) --build-arg RUNTIME_IMAGE=amazon/aws-for-fluent-bit:runtime-debug-al${AL_TAG} -t amazon/aws-for-fluent-bit:runtime-debug-common-${AL_TAG} -f ./scripts/dockerfiles/runtime/Dockerfile.debug-common .
#   debug images
	docker build $(DOCKER_BUILD_FLAGS) --build-arg RUNTIME_IMAGE=amazon/aws-for-fluent-bit:runtime-debug-common-${AL_TAG} -t amazon/aws-for-fluent-bit:debug-al${AL_TAG} -f ./scripts/dockerfiles/runtime/Dockerfile.debug .
	docker build $(DOCKER_BUILD_FLAGS) --build-arg COMPILE_IMAGE=amazon/aws-for-fluent-bit:compile-init-al${AL_TAG} --build-arg RUNTIME_IMAGE=amazon/aws-for-fluent-bit:debug-al${AL_TAG} -t amazon/aws-for-fluent-bit:runtime-init-debug-al${AL_TAG} -f ./scripts/dockerfiles/runtime/Dockerfile.init .
	docker build $(DOCKER_BUILD_FLAGS) --build-arg RUNTIME_IMAGE=amazon/aws-for-fluent-bit:runtime-init-debug-al${AL_TAG} -t amazon/aws-for-fluent-bit:init-debug-al${AL_TAG} -f ./scripts/dockerfiles/runtime/Dockerfile.init-debug .

.PHONY: debug-valgrind
debug-valgrind: debug
	docker build $(DOCKER_BUILD_FLAGS) --build-arg RUNTIME_IMAGE=amazon/aws-for-fluent-bit:runtime-debug-common-${AL_TAG} -t amazon/aws-for-fluent-bit:debug-valgrind-al${AL_TAG} -f ./scripts/dockerfiles/runtime/Dockerfile.debug-valgrind .

.PHONY: cloudwatch-dev
cloudwatch-dev: export OS_TYPE = linux
cloudwatch-dev: build
	./scripts/build_plugins.sh \
    	--CLOUDWATCH_PLUGIN_CLONE_URL=${CLOUDWATCH_PLUGIN_CLONE_URL} \
    	--CLOUDWATCH_PLUGIN_BRANCH=${CLOUDWATCH_PLUGIN_BRANCH} \
    	--DOCKER_BUILD_FLAGS=${DOCKER_BUILD_FLAGS}
	docker build $(DOCKER_BUILD_FLAGS) --build-arg OS_DIGEST=${OS_DIGEST} -t amazon/aws-for-fluent-bit:runtime-deps-al${AL_TAG} -f ./scripts/dockerfiles/runtime/Dockerfile.deps-al${AL_TAG} .
	docker build $(DOCKER_BUILD_FLAGS) --build-arg COMPILE_IMAGE=amazon/aws-for-fluent-bit:compile-al${AL_TAG} --build-arg RUNTIME_IMAGE=amazon/aws-for-fluent-bit:runtime-deps-al${AL_TAG} --build-arg FLB_VERSION=${FLB_VERSION} --build-arg AWS_FOR_FLUENT_BIT_VERSION=${AWS_FOR_FLUENT_BIT_VERSION} --build-arg OS_PRETTY_NAME=${OS_PRETTY_NAME} --build-arg OS_IMAGE_ID=${OS_IMAGE_ID} --build-arg OS_DIGEST=${OS_DIGEST} -t amazon/aws-for-fluent-bit:latest-al${AL_TAG} -f ./scripts/dockerfiles/runtime/Dockerfile .

.PHONY: firehose-dev
firehose-dev: export OS_TYPE = linux
firehose-dev: build
	./scripts/build_plugins.sh \
    	--FIREHOSE_PLUGIN_CLONE_URL=${FIREHOSE_PLUGIN_CLONE_URL} \
    	--FIREHOSE_PLUGIN_BRANCH=${FIREHOSE_PLUGIN_BRANCH} \
    	--DOCKER_BUILD_FLAGS=${DOCKER_BUILD_FLAGS}
	docker build $(DOCKER_BUILD_FLAGS) --build-arg OS_DIGEST=${OS_DIGEST} -t amazon/aws-for-fluent-bit:runtime-deps-al${AL_TAG} -f ./scripts/dockerfiles/runtime/Dockerfile.deps-al${AL_TAG} .
	docker build $(DOCKER_BUILD_FLAGS) --build-arg COMPILE_IMAGE=amazon/aws-for-fluent-bit:compile-al${AL_TAG} --build-arg RUNTIME_IMAGE=amazon/aws-for-fluent-bit:runtime-deps-al${AL_TAG} --build-arg FLB_VERSION=${FLB_VERSION} --build-arg AWS_FOR_FLUENT_BIT_VERSION=${AWS_FOR_FLUENT_BIT_VERSION} --build-arg OS_PRETTY_NAME=${OS_PRETTY_NAME} --build-arg OS_IMAGE_ID=${OS_IMAGE_ID} --build-arg OS_DIGEST=${OS_DIGEST} -t amazon/aws-for-fluent-bit:latest-al${AL_TAG} -f ./scripts/dockerfiles/runtime/Dockerfile .

.PHONY: kinesis-dev
kinesis-dev: export OS_TYPE = linux
kinesis-dev: build
	./scripts/build_plugins.sh \
    	--KINESIS_PLUGIN_CLONE_URL=${KINESIS_PLUGIN_CLONE_URL} \
    	--KINESIS_PLUGIN_BRANCH=${KINESIS_PLUGIN_BRANCH} \
    	--DOCKER_BUILD_FLAGS=${DOCKER_BUILD_FLAGS}
	docker build $(DOCKER_BUILD_FLAGS) --build-arg OS_DIGEST=${OS_DIGEST} -t amazon/aws-for-fluent-bit:runtime-deps-al${AL_TAG} -f ./scripts/dockerfiles/runtime/Dockerfile.deps-al${AL_TAG} .
	docker build $(DOCKER_BUILD_FLAGS) --build-arg COMPILE_IMAGE=amazon/aws-for-fluent-bit:compile-al${AL_TAG} --build-arg RUNTIME_IMAGE=amazon/aws-for-fluent-bit:runtime-deps-al${AL_TAG} --build-arg FLB_VERSION=${FLB_VERSION} --build-arg AWS_FOR_FLUENT_BIT_VERSION=${AWS_FOR_FLUENT_BIT_VERSION} --build-arg OS_PRETTY_NAME=${OS_PRETTY_NAME} --build-arg OS_IMAGE_ID=${OS_IMAGE_ID} --build-arg OS_DIGEST=${OS_DIGEST} -t amazon/aws-for-fluent-bit:latest-al${AL_TAG} -f ./scripts/dockerfiles/runtime/Dockerfile .

.PHONY: validate-version-file-format
validate-version-file-format:
	jq -e . windows.versions && true || false
	jq -e . linux.version && true || false

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
	rm -rf ./build ./integ/out
# Remove all amazon/aws-for-fluent-bit tagged images
	docker images --format "table {{.Repository}}:{{.Tag}}" | grep "^amazon/aws-for-fluent-bit:" | xargs -r docker image remove -f
# Remove aws-fluent-bit-plugins images
	docker images --format "table {{.Repository}}:{{.Tag}}" | grep "^aws-fluent-bit-plugins:" | xargs -r docker image remove -f
# Clean up dangling images
	docker image prune -a -f
