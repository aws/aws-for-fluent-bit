#!/bin/bash
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

set -xeuo pipefail

scripts=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${scripts}"

IMAGE_SHA_MATCHED="FALSE"
AWS_FOR_FLUENT_BIT_VERSION=$(cat ../AWS_FOR_FLUENT_BIT_VERSION)
AWS_FOR_FLUENT_BIT_STABLE_VERSION=$(cat ../AWS_FOR_FLUENT_BIT_STABLE_VERSION)

docker_hub_image_tags=$(curl -s -S 'https://registry.hub.docker.com/v2/repositories/amazon/aws-for-fluent-bit/tags/?page=1&page_size=250' | jq -r '.results[].name')
tag_array=(`echo ${docker_hub_image_tags}`)
AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB=$(./get_latest_dockerhub_version.py ${tag_array[@]})

# Enforce STS regional endpoints
AWS_STS_REGIONAL_ENDPOINTS=regional

classic_regions="
us-east-1
eu-west-1
us-west-1
ap-southeast-1
ap-northeast-1
us-west-2
sa-east-1
ap-southeast-2
eu-central-1
ap-northeast-2
ap-south-1
us-east-2
ca-central-1
eu-west-2
eu-west-3
eu-north-1
ap-northeast-3
"

classic_regions_account_id="906394416424"

cn_regions="
cn-north-1
cn-northwest-1
"

cn_regions_account_id="128054284489"

gov_regions="
us-gov-east-1
us-gov-west-1
"

gov_regions_account_id="161423150738"

hongkong_region="ap-east-1"

hongkong_account_id="449074385750"

bahrain_region="me-south-1"

bahrain_account_id="741863432321"

cape_town_region="af-south-1"

cape_town_account_id="928143927712"

milan_region="eu-south-1"

milan_account_id="960320637246"

gamma_region="us-west-2"

gamma_account_id="626332813196"

DOCKER_HUB_SECRET="com.amazonaws.dockerhub.aws-for-fluent-bit.credentials"

ARCHITECTURES=("amd64" "arm64")

docker_hub_login() {
	username="$(aws secretsmanager get-secret-value --secret-id $DOCKER_HUB_SECRET --region us-west-2 | jq -r '.SecretString | fromjson.username')"
	password="$(aws secretsmanager get-secret-value --secret-id $DOCKER_HUB_SECRET --region us-west-2 | jq -r '.SecretString | fromjson.password')"

	# Logout when the script exits
	trap cleanup EXIT
	cleanup() {
		docker logout
	}

	# login to DockerHub
	docker login -u "${username}" --password "${password}"
}

publish_to_docker_hub() {
	export DOCKER_CLI_EXPERIMENTAL=enabled

	docker_hub_login

	if [ $# -eq 2 ]; then
		# Get the image SHA's
		docker pull ${1}:stable || echo "0"
		sha1=$(docker inspect --format='{{index .RepoDigests 0}}' ${1}:stable || echo "0")
		docker pull ${1}:${AWS_FOR_FLUENT_BIT_STABLE_VERSION}
		sha2=$(docker inspect --format='{{index .RepoDigests 0}}' ${1}:${AWS_FOR_FLUENT_BIT_STABLE_VERSION})

		match_two_sha $sha1 $sha2

		if [ "$IMAGE_SHA_MATCHED" = "FALSE" ]; then
			create_manifest_list ${1} "stable" ${AWS_FOR_FLUENT_BIT_STABLE_VERSION}
		fi
	else
		for arch in "${ARCHITECTURES[@]}"
		do
			docker tag ${1}:"$arch" ${1}:"${arch}"-${AWS_FOR_FLUENT_BIT_VERSION}
			docker push ${1}:"$arch"-${AWS_FOR_FLUENT_BIT_VERSION}
		done

		create_manifest_list ${1} "latest" ${AWS_FOR_FLUENT_BIT_VERSION}
		create_manifest_list ${1} ${AWS_FOR_FLUENT_BIT_VERSION} ${AWS_FOR_FLUENT_BIT_VERSION}
	fi
}

publish_to_public_ecr() {
	if [ $# -eq 2 ]; then
		aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/aws-observability
		docker pull public.ecr.aws/aws-observability/aws-for-fluent-bit:stable || echo "0"
		sha1=$(docker inspect --format='{{index .RepoDigests 0}}' public.ecr.aws/aws-observability/aws-for-fluent-bit:stable || echo "0")
		docker pull public.ecr.aws/aws-observability/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_STABLE_VERSION}
		sha2=$(docker inspect --format='{{index .RepoDigests 0}}' public.ecr.aws/aws-observability/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_STABLE_VERSION})

		match_two_sha $sha1 $sha2

		if [ "$IMAGE_SHA_MATCHED" = "FALSE" ]; then
			aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/aws-observability
			create_manifest_list public.ecr.aws/aws-observability/aws-for-fluent-bit "stable" ${AWS_FOR_FLUENT_BIT_STABLE_VERSION}
		fi
	else
		aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/aws-observability

		for arch in "${ARCHITECTURES[@]}"
		do
			docker tag ${1}:"$arch" public.ecr.aws/aws-observability/aws-for-fluent-bit:"$arch"-${AWS_FOR_FLUENT_BIT_VERSION}
			docker push public.ecr.aws/aws-observability/aws-for-fluent-bit:"$arch"-${AWS_FOR_FLUENT_BIT_VERSION}
		done

		create_manifest_list public.ecr.aws/aws-observability/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION} ${AWS_FOR_FLUENT_BIT_VERSION}
		aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/aws-observability
		create_manifest_list public.ecr.aws/aws-observability/aws-for-fluent-bit "latest" ${AWS_FOR_FLUENT_BIT_VERSION}
	fi
}

publish_ssm() {
	aws ssm put-parameter --name /aws/service/aws-for-fluent-bit/${3} --overwrite \
		--description 'Regional Amazon ECR Image URI for the latest AWS for Fluent Bit Docker Image' \
		--type String --region ${1} --value ${2}:${3}
	aws ssm put-parameter --name /aws/service/aws-for-fluent-bit/latest --overwrite \
		--description 'Regional Amazon ECR Image URI for the latest AWS for Fluent Bit Docker Image' \
		--type String --region ${1} --value ${2}:latest
}

publish_stable_ssm() {
	aws ssm put-parameter --name /aws/service/aws-for-fluent-bit/stable --overwrite \
		--description 'Regional Amazon ECR Image URI for the latest stable AWS for Fluent Bit Docker Image' \
		--type String --region ${1} --value ${2}:${3}
}

rollback_ssm() {
	aws ssm delete-parameter --name /aws/service/aws-for-fluent-bit/${AWS_FOR_FLUENT_BIT_VERSION} --region ${1}
}

check_parameter() {
	repo_uri=$(aws ssm get-parameter --name /aws/service/aws-for-fluent-bit/${2} --region ${1} --query 'Parameter.Value')
	IFS='.' read -r -a array <<<"$repo_uri"
	region="${array[3]}"
	if [ "${1}" != "${region}" ]; then
		echo "${1}: Region found in repo URI does not match SSM Parameter region: ${repo_uri}"
		exit 1
	fi
	# remove leading and trailing quotes from repo_uri
	repo_uri=$(sed -e 's/^"//' -e 's/"$//' <<<"$repo_uri")
	docker pull $repo_uri
}

sync_latest_image() {
	region=${1}
	account_id=${2}

	endpoint='amazonaws.com'
	if [ "${1}" = "cn-north-1" ] || [ "${1}" = "cn-northwest-1" ]; then
		endpoint=${endpoint}.cn
	fi
	
	for arch in "${ARCHITECTURES[@]}"
	do
		aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/aws-observability || echo "0"
		docker pull public.ecr.aws/aws-observability/aws-for-fluent-bit:"$arch"-${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
		sha1=$(docker inspect --format='{{index .RepoDigests 0}}' public.ecr.aws/aws-observability/aws-for-fluent-bit:"$arch"-${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB})
		aws ecr get-login-password --region ${region}| docker login --username AWS --password-stdin ${account_id}.dkr.ecr.${region}.${endpoint}
		repoList=$(aws ecr describe-repositories --region ${region})
		repoName=$(echo $repoList | jq .repositories[0].repositoryName)
		if [ "$repoName" = '"aws-for-fluent-bit"' ]; then
			imageTag=$(aws ecr list-images  --repository-name aws-for-fluent-bit --region ${region} | jq -r '.imageIds[].imageTag' | grep -c ${arch}-${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB} || echo "0")
			if [ "$imageTag" = '1' ]; then
				docker pull ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${arch}-${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
				sha2=$(docker inspect --format='{{index .RepoDigests 0}}' ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${arch}-${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB})
			else
				sha2='repo_not_found'
			fi
		else
			sha2='repo_not_found'
		fi

		match_two_sha $sha1 $sha2

		if [ "$IMAGE_SHA_MATCHED" = "FALSE" ]; then
			aws ecr create-repository --repository-name aws-for-fluent-bit --image-scanning-configuration scanOnPush=true --region ${region}  || true
			push_image_ecr public.ecr.aws/aws-observability/aws-for-fluent-bit:"$arch"-${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB} \
				${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${arch}-${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
		fi
	done

	if [ "${account_id}" != "${classic_regions_account_id}" ]; then
		create_manifest_list ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit "latest" ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
		create_manifest_list ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB} ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
	fi
	create_manifest_list ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit "stable" ${AWS_FOR_FLUENT_BIT_STABLE_VERSION} || echo "0"

	make_repo_public ${region}

	ssm_parameters=$(aws ssm get-parameters --names "/aws/service/aws-for-fluent-bit/${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}" --region ${region})
	invalid_parameter=$(echo $ssm_parameters | jq .InvalidParameters[0])
	if [ "$invalid_parameter" != 'null' ]; then
		publish_ssm ${region} ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
	fi

	ssm_parameters=$(aws ssm get-parameters --names "/aws/service/aws-for-fluent-bit/stable" --region ${region})
	invalid_parameter=$(echo $ssm_parameters | jq .InvalidParameters[0])
	if [ "$invalid_parameter" != 'null' ]; then
		publish_stable_ssm ${region} ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_STABLE_VERSION}
	fi

	stable_uri=$(aws ssm get-parameters --names /aws/service/aws-for-fluent-bit/stable --region ${region} --query 'Parameters[0].Value')
	stable_uri=$(sed -e 's/^"//' -e 's/"$//' <<<"$stable_uri")

	if [ "$stable_uri" != "${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_STABLE_VERSION}" ]; then
		publish_stable_ssm ${region} ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_STABLE_VERSION}
	fi
}

verify_ssm() {
	is_sync_task=${2:-false}

	endpoint='amazonaws.com'
	if [ "${1}" = "cn-north-1" ] || [ "${1}" = "cn-northwest-1" ]; then
		endpoint=${endpoint}.cn
	fi
	aws ecr get-login-password --region ${1} | docker login --username AWS --password-stdin ${3}.dkr.ecr.${1}.${endpoint}

	check_parameter ${1} latest

	if [ "${is_sync_task}" = "true" ]; then
		check_parameter ${1} ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
		check_parameter ${1} stable
	else
		check_parameter ${1} ${AWS_FOR_FLUENT_BIT_VERSION}
	fi
}

create_manifest_list() {

	export DOCKER_CLI_EXPERIMENTAL=enabled
	tag=${2}
	version=${3}

	# TODO: Add a way to automatically generate arch images in manifest
	docker manifest create ${1}:${tag} ${1}:arm64-${version} ${1}:amd64-${version}

	for arch in "${ARCHITECTURES[@]}"
	do
		docker manifest annotate --arch "$arch" ${1}:${tag} ${1}:"$arch"-${version}
	done

	# sanity check on the debug log.
 	docker manifest inspect ${1}:${tag}
	docker manifest push ${1}:${tag}
}

push_image_ecr() {
	docker tag ${1} ${2}
    	docker push ${2}
}

make_repo_public() {
	aws ecr set-repository-policy --repository-name aws-for-fluent-bit --policy-text file://public_repo_policy.json --region ${1}
}

publish_ecr() {
	region=${1}
	account_id=${2}

	aws ecr get-login-password --region ${region}| docker login --username AWS --password-stdin ${account_id}.dkr.ecr.${region}.amazonaws.com
	aws ecr create-repository --repository-name aws-for-fluent-bit --image-scanning-configuration scanOnPush=true --region ${region}  || true

	for arch in "${ARCHITECTURES[@]}"
	do
		push_image_ecr ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:"$arch" \
			${account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit:"$arch"-${AWS_FOR_FLUENT_BIT_VERSION}
	done

	create_manifest_list ${account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION} ${AWS_FOR_FLUENT_BIT_VERSION}
	create_manifest_list ${account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit "latest" ${AWS_FOR_FLUENT_BIT_VERSION}

	make_repo_public ${region}
}

verify_ecr() {
	region=${1}
	account_id=${2}
	is_sync_task=${3:-false}

	endpoint='amazonaws.com'
	if [ "${1}" = "cn-north-1" ] || [ "${1}" = "cn-northwest-1" ]; then
		endpoint=${endpoint}.cn
	fi
	aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin ${account_id}.dkr.ecr.${region}.${endpoint}

	if [ "${is_sync_task}" = "true" ]; then
		docker pull ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:stable || echo "0"
		stableSha1=$(docker inspect --format='{{index .RepoDigests 0}}' ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:stable || echo "0")
		docker pull ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_STABLE_VERSION} || echo "0"
		stableSha2=$(docker inspect --format='{{index .RepoDigests 0}}' ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_STABLE_VERSION} || echo "0")

		verify_sha $stableSha1 $stableSha2

		docker pull ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
		sha1=$(docker inspect --format='{{index .RepoDigests 0}}' ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB})
	else
		docker pull ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION}
		sha1=$(docker inspect --format='{{index .RepoDigests 0}}' ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION})
	fi
	docker pull ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:latest
	sha2=$(docker inspect --format='{{index .RepoDigests 0}}' ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:latest)

	verify_sha $sha1 $sha2
}

check_image_version() {
	export DOCKER_CLI_EXPERIMENTAL=enabled
	EXIT_CODE=0

	docker_hub_login
	
	# check if we can get the image information in dockerhub; if yes, the exit status should be 0
	docker manifest inspect amazon/aws-for-fluent-bit:${1} > /dev/null || EXIT_CODE=$?
	if [ "${EXIT_CODE}" = "0" ]; then
		echo "Accidental release: current image version from github source file match a previous version from dockerhub."
		exit 1
	fi

	echo "Approved release: release the image with a new version."
}

verify_ecr_image_scan() {
	region=${1}
	repo_uri=${2}
	tag=${3}

	imageTag=$(aws ecr list-images  --repository-name ${repo_uri} --region ${region} | jq -r '.imageIds[].imageTag' | grep -c ${tag} || echo "0")
	if [ "$imageTag" = '1' ]; then
		aws ecr start-image-scan --repository-name ${repo_uri} --image-id imageTag=${tag} --region ${region}
		aws ecr wait image-scan-complete --repository-name ${repo_uri} --region ${region} --image-id imageTag=${tag}
		highVulnerabilityCount=$(aws ecr describe-image-scan-findings --repository-name ${repo_uri} --region ${region} --image-id imageTag=${tag} | jq '.imageScanFindings.findingSeverityCounts.HIGH')
		criticalVulnerabilityCount=$(aws ecr describe-image-scan-findings --repository-name ${repo_uri} --region ${region} --image-id imageTag=${tag} | jq '.imageScanFindings.findingSeverityCounts.CRITICAL')
		if [ "$highVulnerabilityCount" != null ] || [ "$criticalVulnerabilityCount" != null ]; then
			echo "Uploaded image ${tag} has ${vulnerabilityCount} vulnerabilities."
			exit 1
		fi
	fi
}

verify_dockerhub() {
	docker_hub_login
	
	# Verify the image with stable tag
	if [ $# -eq 1 ]; then
		# Get the image SHA's
		docker pull amazon/aws-for-fluent-bit:stable
		sha1=$(docker inspect --format='{{index .RepoDigests 0}}' amazon/aws-for-fluent-bit:stable)
		docker pull amazon/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_STABLE_VERSION}
		sha2=$(docker inspect --format='{{index .RepoDigests 0}}' amazon/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_STABLE_VERSION})

		verify_sha $sha1 $sha2
	else
		# Get the image SHA's
		docker pull amazon/aws-for-fluent-bit:latest
		sha1=$(docker inspect --format='{{index .RepoDigests 0}}' amazon/aws-for-fluent-bit:latest)
		docker pull amazon/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION}
		sha2=$(docker inspect --format='{{index .RepoDigests 0}}' amazon/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION})

		verify_sha $sha1 $sha2
	fi
}

verify_public_ecr() {
	aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/aws-observability || echo "0"

	# Verify the image with stable tag
	if [ $# -eq 1 ]; then
		# Get the image SHA's
		docker pull public.ecr.aws/aws-observability/aws-for-fluent-bit:stable
		sha1=$(docker inspect --format='{{index .RepoDigests 0}}' public.ecr.aws/aws-observability/aws-for-fluent-bit:stable)
		docker pull public.ecr.aws/aws-observability/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_STABLE_VERSION}
		sha2=$(docker inspect --format='{{index .RepoDigests 0}}' public.ecr.aws/aws-observability/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_STABLE_VERSION})

		verify_sha $sha1 $sha2
	else
		# Get the image SHA's
		docker pull public.ecr.aws/aws-observability/aws-for-fluent-bit:latest
		sha1=$(docker inspect --format='{{index .RepoDigests 0}}' public.ecr.aws/aws-observability/aws-for-fluent-bit:latest)
		docker pull public.ecr.aws/aws-observability/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION}
		sha2=$(docker inspect --format='{{index .RepoDigests 0}}' public.ecr.aws/aws-observability/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION})

		verify_sha $sha1 $sha2
	fi
}

verify_sha() {
	sha1=${1}
	sha2=${2}

	match_two_sha $sha1 $sha2

	if [ "$IMAGE_SHA_MATCHED" = "TRUE" ]; then
		echo '[Publish Verification] Successfull'
		IMAGE_SHA_MATCHED="FALSE"
	else
		echo '[Publish Verification] Failed'
		exit 1
	fi
}

match_two_sha() {
	sha1=${1}
	sha2=${2}

	# Get the last 64 chars of the SHA string
	last64_1=$(echo $sha1 | egrep -o '.{1,64}$')
	last64_2=$(echo $sha2 | egrep -o '.{1,64}$')

	if [ "$last64_1" = "$last64_2" ]; then
		IMAGE_SHA_MATCHED="TRUE"
	else
		IMAGE_SHA_MATCHED="FALSE"
	fi
}


if [ "${1}" = "publish" ]; then
	if [ "${2}" = "dockerhub" ]; then
		publish_to_docker_hub amazon/aws-for-fluent-bit
	fi

	if [ "${2}" = "aws" ]; then
		for region in ${classic_regions}; do
			publish_ecr ${region} ${classic_regions_account_id}
		done
	fi

	if [ "${2}" = "aws-cn" ]; then
		for region in ${cn_regions}; do
			publish_ecr ${region} ${cn_regions_account_id}
		done
	fi

	if [ "${2}" = "aws-us-gov" ]; then
		for region in ${gov_regions}; do
			publish_ecr ${region} ${gov_regions_account_id}
		done
	fi

	if [ "${2}" = "${hongkong_region}" ]; then
		publish_ecr ${hongkong_region} ${hongkong_account_id}
	fi

	if [ "${2}" = "${bahrain_region}" ]; then
		publish_ecr ${bahrain_region} ${bahrain_account_id}
	fi

	if [ "${2}" = "${cape_town_region}" ]; then
		publish_ecr ${cape_town_region} ${cape_town_account_id}
	fi

	if [ "${2}" = "${milan_region}" ]; then
		publish_ecr ${milan_region} ${milan_account_id}
	fi

	if [ "${2}" = "gamma" ]; then
		publish_ecr ${gamma_region} ${gamma_account_id}
	fi
fi

if [ "${1}" = "verify" ]; then
	if [ "${2}" = "dockerhub" ]; then
		docker pull amazon/aws-for-fluent-bit:latest
		docker pull amazon/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION}
	fi
	if [ "${2}" = "aws" ]; then
		for region in ${classic_regions}; do
			verify_ecr ${region} ${classic_regions_account_id}
		done
	fi

	if [ "${2}" = "aws-cn" ]; then
		for region in ${cn_regions}; do
			verify_ecr ${region} ${cn_regions_account_id}
		done
	fi

	if [ "${2}" = "aws-us-gov" ]; then
		for region in ${gov_regions}; do
			verify_ecr ${region} ${gov_regions_account_id}
		done
	fi

	if [ "${2}" = "${hongkong_region}" ]; then
		verify_ecr ${hongkong_region} ${hongkong_account_id}
	fi

	if [ "${2}" = "${bahrain_region}" ]; then
		verify_ecr ${bahrain_region} ${bahrain_account_id}
	fi

	if [ "${2}" = "${cape_town_region}" ]; then
		verify_ecr ${cape_town_region} ${cape_town_account_id}
	fi

	if [ "${2}" = "${milan_region}" ]; then
		verify_ecr ${milan_region} ${milan_account_id}
	fi

	if [ "${2}" = "gamma" ]; then
		verify_ecr ${gamma_region} ${gamma_account_id}
	fi
fi

if [ "${1}" = "publish-ssm" ]; then
	if [ "${2}" = "aws" ]; then
		for region in ${classic_regions}; do
			publish_ssm ${region} ${classic_regions_account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION}
		done
	fi

	if [ "${2}" = "aws-cn" ]; then
		for region in ${cn_regions}; do
			publish_ssm ${region} ${cn_regions_account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
		done
	fi

	if [ "${2}" = "aws-us-gov" ]; then
		for region in ${gov_regions}; do
			publish_ssm ${region} ${gov_regions_account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
		done
	fi

	if [ "${2}" = "${hongkong_region}" ]; then
		publish_ssm ${hongkong_region} ${hongkong_account_id}.dkr.ecr.${hongkong_region}.amazonaws.com/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
	fi

	if [ "${2}" = "${bahrain_region}" ]; then
		publish_ssm ${bahrain_region} ${bahrain_account_id}.dkr.ecr.${bahrain_region}.amazonaws.com/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
	fi

	if [ "${2}" = "${cape_town_region}" ]; then
		publish_ssm ${cape_town_region} ${cape_town_account_id}.dkr.ecr.${cape_town_region}.amazonaws.com/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
	fi

	if [ "${2}" = "${milan_region}" ]; then
		publish_ssm ${milan_region} ${milan_account_id}.dkr.ecr.${milan_region}.amazonaws.com/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
	fi
fi

if [ "${1}" = "verify-ssm" ]; then
	if [ "${2}" = "aws" ]; then
		for region in ${classic_regions}; do
			verify_ssm ${region} false ${classic_regions_account_id}
		done
	fi

	if [ "${2}" = "aws-cn" ]; then
		for region in ${cn_regions}; do
			verify_ssm ${region} false ${cn_regions_account_id}
		done
	fi

	if [ "${2}" = "aws-us-gov" ]; then
		for region in ${gov_regions}; do
			verify_ssm ${region} false ${gov_regions_account_id}
		done
	fi

	if [ "${2}" = "${hongkong_region}" ]; then
		verify_ssm ${hongkong_region} false ${hongkong_account_id}
	fi

	if [ "${2}" = "${bahrain_region}" ]; then
		verify_ssm ${bahrain_region} false ${bahrain_account_id}
	fi

	if [ "${2}" = "${cape_town_region}" ]; then
		verify_ssm ${cape_town_region} false ${cape_town_account_id}
	fi

	if [ "${2}" = "${milan_region}" ]; then
		verify_ssm ${milan_region} false ${milan_account_id}
	fi
fi

if [ "${1}" = "rollback-ssm" ]; then
	if [ "${2}" = "aws" ]; then
		for region in ${classic_regions}; do
			rollback_ssm ${region}
		done
	fi

	if [ "${2}" = "aws-cn" ]; then
		for region in ${cn_regions}; do
			rollback_ssm ${region}
		done
	fi

	if [ "${2}" = "aws-us-gov" ]; then
		for region in ${gov_regions}; do
			rollback_ssm ${region}
		done
	fi

	if [ "${2}" = "${hongkong_region}" ]; then
		rollback_ssm ${hongkong_region}
	fi

	if [ "${2}" = "${bahrain_region}" ]; then
		rollback_ssm ${bahrain_region}
	fi

	if [ "${2}" = "${cape_town_region}" ]; then
		rollback_ssm ${cape_town_region}
	fi

	if [ "${2}" = "${milan_region}" ]; then
		rollback_ssm ${milan_region}
	fi
fi

# Publish using CI/CD pipeline
# Following scripts will be called only from the CI/CD pipeline
if [ "${1}" = "cicd-publish" ]; then
	if [ "${2}" = "dockerhub" ]; then
		publish_to_docker_hub amazon/aws-for-fluent-bit
	elif [ "${2}" = "public-ecr" ]; then
		publish_to_public_ecr amazon/aws-for-fluent-bit
	elif [ "${2}" = "us-gov-east-1" ] || [ "${2}" = "us-gov-west-1" ]; then
		for region in ${gov_regions}; do
			sync_latest_image ${region} ${gov_regions_account_id}
		done
	elif [ "${2}" = "cn-north-1" ] || [ "${2}" = "cn-northwest-1" ]; then
		for region in ${cn_regions}; do
			sync_latest_image ${region} ${cn_regions_account_id}
		done
	elif [ "${2}" = "${bahrain_region}" ]; then
		sync_latest_image ${bahrain_region} ${bahrain_account_id}
	elif [ "${2}" = "${hongkong_region}" ]; then
		sync_latest_image ${hongkong_region} ${hongkong_account_id}
	elif [ "${2}" = "${cape_town_region}" ]; then
		sync_latest_image ${cape_town_region} ${cape_town_account_id}
	elif [ "${2}" = "${milan_region}" ]; then
		sync_latest_image ${milan_region} ${milan_account_id}
	elif [ $# -eq 3 ] && [ "${3}" = "stable" ]; then
		for region in ${classic_regions}; do
			sync_latest_image ${region} ${classic_regions_account_id}
		done
	elif [ $# -eq 3 ] && [ "${2}" = "public-dockerhub-stable" ]; then
		if [ "${3}" = "us-west-2" ]; then
			publish_to_docker_hub amazon/aws-for-fluent-bit stable
		fi
	elif [ $# -eq 3 ] && [ "${2}" = "public-ecr-stable" ]; then
		if [ "${3}" = "us-west-2" ]; then
			publish_to_public_ecr amazon/aws-for-fluent-bit stable
		fi
	else
		publish_ecr "${2}" ${classic_regions_account_id}
	fi
fi

# Verify using CI/CD pipeline
if [ "${1}" = "cicd-verify" ]; then
	if [ "${2}" = "dockerhub" ]; then
		verify_dockerhub
	elif [ "${2}" = "public-ecr" ]; then
		verify_public_ecr
	elif [ "${2}" = "us-gov-east-1" ] || [ "${2}" = "us-gov-west-1" ]; then
		for region in ${gov_regions}; do
			verify_ecr ${region} ${gov_regions_account_id} true
		done
	elif [ "${2}" = "cn-north-1" ] || [ "${2}" = "cn-northwest-1" ]; then
		for region in ${cn_regions}; do
			verify_ecr ${region} ${cn_regions_account_id} true
		done
	elif [ "${2}" = "${bahrain_region}" ]; then
		verify_ecr ${bahrain_region} ${bahrain_account_id} true
	elif [ "${2}" = "${hongkong_region}" ]; then
		verify_ecr ${hongkong_region} ${hongkong_account_id} true
	elif [ "${2}" = "${cape_town_region}" ]; then
		verify_ecr ${cape_town_region} ${cape_town_account_id} true
	elif [ "${2}" = "${milan_region}" ]; then
		verify_ecr ${milan_region} ${milan_account_id} true
	elif [ $# -eq 3 ] && [ "${3}" = "stable" ]; then
		for region in ${classic_regions}; do
			verify_ecr ${region} ${classic_regions_account_id} true
		done
	elif [ "${2}" = "stable" ]; then
		if [ "${3}" = "us-west-2" ]; then
			verify_dockerhub stable
			verify_public_ecr stable
		fi
	else
		verify_ecr "${2}" ${classic_regions_account_id}
	fi
fi

# Publish SSM parameters
if [ "${1}" = "cicd-publish-ssm" ]; then
	if [ "${2}" = "us-gov-east-1" ] || [ "${2}" = "us-gov-west-1" ]; then
		for region in ${gov_regions}; do
			publish_ssm ${region} ${gov_regions_account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
		done
	elif [ "${2}" = "cn-north-1" ] || [ "${2}" = "cn-northwest-1" ]; then
		for region in ${cn_regions}; do
			publish_ssm ${region} ${cn_regions_account_id}.dkr.ecr.${region}.amazonaws.com.cn/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
		done
	elif [ "${2}" = "${bahrain_region}" ]; then
		publish_ssm ${bahrain_region} ${bahrain_account_id}.dkr.ecr.${bahrain_region}.amazonaws.com/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
	elif [ "${2}" = "${hongkong_region}" ]; then
		publish_ssm ${hongkong_region} ${hongkong_account_id}.dkr.ecr.${hongkong_region}.amazonaws.com/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
	elif [ "${2}" = "${cape_town_region}" ]; then
		publish_ssm ${cape_town_region} ${cape_town_account_id}.dkr.ecr.${cape_town_region}.amazonaws.com/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
	elif [ "${2}" = "${milan_region}" ]; then
		publish_ssm ${milan_region} ${milan_account_id}.dkr.ecr.${milan_region}.amazonaws.com/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION_DOCKERHUB}
	else
		for region in ${classic_regions}; do
			publish_ssm ${region} ${classic_regions_account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION}
		done
	fi
fi

# Verify SSM parameters
if [ "${1}" = "cicd-verify-ssm" ]; then
	if [ "${2}" = "us-gov-east-1" ] || [ "${2}" = "us-gov-west-1" ]; then
		for region in ${gov_regions}; do
			verify_ssm ${region} true ${gov_regions_account_id}
		done
	elif [ "${2}" = "cn-north-1" ] || [ "${2}" = "cn-northwest-1" ]; then
		for region in ${cn_regions}; do
			verify_ssm ${region} true ${cn_regions_account_id}
		done
	elif [ "${2}" = "${bahrain_region}" ]; then
		verify_ssm ${bahrain_region} true ${bahrain_account_id}
	elif [ "${2}" = "${hongkong_region}" ]; then
		verify_ssm ${hongkong_region} true ${hongkong_account_id}
	elif [ "${2}" = "${cape_town_region}" ]; then
		verify_ssm ${cape_town_region} true ${cape_town_account_id}
	elif [ "${2}" = "${milan_region}" ]; then
		verify_ssm ${milan_region} true ${milan_account_id}
	elif [ $# -eq 3 ]; then
		for region in ${classic_regions}; do
			verify_ssm ${region} true ${classic_regions_account_id}
		done
	else
		for region in ${classic_regions}; do
			verify_ssm ${region} false ${classic_regions_account_id}
		done
	fi
fi

if [ "${1}" = "cicd-verify-ecr-image-scan" ]; then
	verify_ecr_image_scan ${2} ${3} ${4}
fi

if [ "${1}" = "cicd-check-image-version" ]; then
	check_image_version ${AWS_FOR_FLUENT_BIT_VERSION} 
fi