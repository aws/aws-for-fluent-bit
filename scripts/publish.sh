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

gamma_region="us-west-2"

gamma_account_id="626332813196"

DOCKER_HUB_SECRET="com.amazonaws.dockerhub.aws-for-fluent-bit.credentials"

publish_to_docker_hub() {
	DRY_RUN="${DRY_RUN:-true}"

	username="$(aws secretsmanager get-secret-value --secret-id $DOCKER_HUB_SECRET --region us-west-2 | jq -r '.SecretString | fromjson.username')"
	password="$(aws secretsmanager get-secret-value --secret-id $DOCKER_HUB_SECRET --region us-west-2 | jq -r '.SecretString | fromjson.password')"

	# Logout when the script exits
	trap cleanup EXIT
	cleanup() {
		docker logout
	}

	# login to DockerHub
	docker login -u "${username}" --password "${password}"

	# Publish to DockerHub only if $DRY_RUN is set to false
	if [[ "${DRY_RUN}" == "false" ]]; then
		docker tag ${1} ${2}
		docker push ${1}
		docker push ${2}
	else
		echo "DRY_RUN: docker tag ${1} ${2}"
		echo "DRY_RUN: docker push ${1}"
		echo "DRY_RUN: docker push ${2}"
		echo "DRY_RUN is NOT set to 'false', skipping DockerHub update. Exiting..."
	fi

}

publish_ssm() {
	aws ssm put-parameter --name /aws/service/aws-for-fluent-bit/${AWS_FOR_FLUENT_BIT_VERSION} --overwrite \
		--description 'Regional Amazon ECR Image URI for the latest AWS for Fluent Bit Docker Image' \
		--type String --region ${1} --value ${2}:${AWS_FOR_FLUENT_BIT_VERSION}
	aws ssm put-parameter --name /aws/service/aws-for-fluent-bit/latest --overwrite \
		--description 'Regional Amazon ECR Image URI for the latest AWS for Fluent Bit Docker Image' \
		--type String --region ${1} --value ${2}:latest
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
	pull_ecr $repo_uri $region
}

sync_latest_image() {
	region=${1}
	account_id=${2}
	sha1=$(docker pull amazon/aws-for-fluent-bit:latest | grep sha256: | cut -f 3 -d :)

	endpoint='amazonaws.com'
	if [ "${1}" = "cn-north-1" ] || [ "${1}" = "cn-northwest-1" ]; then
		endpoint=${endpoint}.cn
	fi

	repoList=$(aws ecr describe-repositories --region ${region})
	repoName=$(echo $repoList | jq .repositories[0].repositoryName)
	if [ "$repoName" = '"aws-for-fluent-bit"' ]; then
		pull_ecr ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:latest ${region}
		sha2=$(docker inspect --format='{{index .RepoDigests 0}}' ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:latest)
	else
		sha2='repo_not_found'
	fi

	docker images
	match_two_sha $sha1 $sha2

	if [ "$IMAGE_SHA_MATCHED" = "FALSE" ]; then
		publish_ecr ${region} ${account_id}
	fi

	ssm_parameters=$(aws ssm get-parameters --names "/aws/service/aws-for-fluent-bit/${AWS_FOR_FLUENT_BIT_VERSION}" --region ${region})
	invalid_parameter=$(echo $ssm_parameters | jq .InvalidParameters[0])
	if [ "$invalid_parameter" != 'null' ]; then
		publish_ssm ${region} ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit
	fi
}

verify_ssm() {
	check_parameter ${1} latest
	check_parameter ${1} ${AWS_FOR_FLUENT_BIT_VERSION}
}

push_to_ecr() {
	docker tag ${1} ${2}
	ecs-cli push ${2} --region ${3} --registry-id ${4}
}

pull_ecr() {
	ecs-cli pull ${1} --region ${2}
}

make_repo_public() {
	aws ecr set-repository-policy --repository-name aws-for-fluent-bit --policy-text file://public_repo_policy.json --region ${1}
}

publish_ecr() {
	region=${1}
	account_id=${2}
	push_to_ecr amazon/aws-for-fluent-bit:latest aws-for-fluent-bit:latest ${region} ${account_id}
	push_to_ecr amazon/aws-for-fluent-bit:latest "aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION}" ${region} ${account_id}
	make_repo_public ${region}
}

verify_ecr() {
	region=${1}
	account_id=${2}

	endpoint='amazonaws.com'
	if [ "${1}" = "cn-north-1" ] || [ "${1}" = "cn-northwest-1" ]; then
		endpoint=${endpoint}.cn
	fi

	pull_ecr ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:latest ${region}
	pull_ecr ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION} ${region}

	#Verification logic matching the image SHA
	sha1=$(docker inspect --format='{{index .RepoDigests 0}}' ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:latest)
	sha2=$(docker inspect --format='{{index .RepoDigests 0}}' ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION})

	verify_sha $sha1 $sha2
}

verify_dockerhub() {
	# Get the image SHA's
	sha1=$(docker pull amazon/aws-for-fluent-bit:latest | grep sha256: | cut -f 3 -d :)
	sha2=$(docker pull amazon/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION} | grep sha256: | cut -f 3 -d :)

	verify_sha $sha1 $sha2
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

AWS_FOR_FLUENT_BIT_VERSION=$(cat ../AWS_FOR_FLUENT_BIT_VERSION)

if [ "${1}" = "publish" ]; then
	if [ "${2}" = "dockerhub" ]; then
		publish_to_docker_hub amazon/aws-for-fluent-bit:latest amazon/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION}
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

	if [ "${2}" = "gamma" ]; then
		verify_ecr ${gamma_region} ${gamma_account_id}
	fi
fi

if [ "${1}" = "publish-ssm" ]; then
	if [ "${2}" = "aws" ]; then
		for region in ${classic_regions}; do
			publish_ssm ${region} ${classic_regions_account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit
		done
	fi

	if [ "${2}" = "aws-cn" ]; then
		for region in ${cn_regions}; do
			publish_ssm ${region} ${cn_regions_account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit
		done
	fi

	if [ "${2}" = "aws-us-gov" ]; then
		for region in ${gov_regions}; do
			publish_ssm ${region} ${gov_regions_account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit
		done
	fi

	if [ "${2}" = "${hongkong_region}" ]; then
		publish_ssm ${hongkong_region} ${hongkong_account_id}.dkr.ecr.${hongkong_region}.amazonaws.com/aws-for-fluent-bit
	fi

	if [ "${2}" = "${bahrain_region}" ]; then
		publish_ssm ${bahrain_region} ${bahrain_account_id}.dkr.ecr.${bahrain_region}.amazonaws.com/aws-for-fluent-bit
	fi
fi

if [ "${1}" = "verify-ssm" ]; then
	if [ "${2}" = "aws" ]; then
		for region in ${classic_regions}; do
			verify_ssm ${region}
		done
	fi

	if [ "${2}" = "aws-cn" ]; then
		for region in ${cn_regions}; do
			verify_ssm ${region}
		done
	fi

	if [ "${2}" = "aws-us-gov" ]; then
		for region in ${gov_regions}; do
			verify_ssm ${region}
		done
	fi

	if [ "${2}" = "${hongkong_region}" ]; then
		verify_ssm ${hongkong_region}
	fi

	if [ "${2}" = "${bahrain_region}" ]; then
		verify_ssm ${bahrain_region}
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
fi

# Publish using CI/CD pipeline
# Following scripts will be called only from the CI/CD pipeline
if [ "${1}" = "cicd-publish" ]; then
	if [ "${2}" = "dockerhub" ]; then
		publish_to_docker_hub amazon/aws-for-fluent-bit:latest amazon/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION}
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
		publish_ecr ${hongkong_region} ${hongkong_account_id}
	else
		publish_ecr "${2}" ${classic_regions_account_id}
	fi
fi

# Verify using CI/CD pipeline
if [ "${1}" = "cicd-verify" ]; then
	if [ "${2}" = "dockerhub" ]; then
		verify_dockerhub
	elif [ "${2}" = "us-gov-east-1" ] || [ "${2}" = "us-gov-west-1" ]; then
		for region in ${gov_regions}; do
			verify_ecr ${region} ${gov_regions_account_id}
		done
	elif [ "${2}" = "cn-north-1" ] || [ "${2}" = "cn-northwest-1" ]; then
		for region in ${cn_regions}; do
			verify_ecr ${region} ${cn_regions_account_id}
		done
	elif [ "${2}" = "${bahrain_region}" ]; then
		verify_ecr ${bahrain_region} ${bahrain_account_id}
	elif [ "${2}" = "${hongkong_region}" ]; then
		verify_ecr ${hongkong_region} ${hongkong_account_id}
	else
		verify_ecr "${2}" ${classic_regions_account_id}
	fi
fi

# Publish SSM parameters
if [ "${1}" = "cicd-publish-ssm" ]; then
	if [ "${2}" = "us-gov-east-1" ] || [ "${2}" = "us-gov-west-1" ]; then
		for region in ${gov_regions}; do
			publish_ssm ${region} ${gov_regions_account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit
		done
	elif [ "${2}" = "cn-north-1" ] || [ "${2}" = "cn-northwest-1" ]; then
		for region in ${cn_regions}; do
			publish_ssm ${region} ${cn_regions_account_id}.dkr.ecr.${region}.amazonaws.com.cn/aws-for-fluent-bit
		done
	elif [ "${2}" = "${bahrain_region}" ]; then
		publish_ssm ${bahrain_region} ${bahrain_account_id}.dkr.ecr.${bahrain_region}.amazonaws.com/aws-for-fluent-bit
	elif [ "${2}" = "${hongkong_region}" ]; then
		publish_ssm ${hongkong_region} ${hongkong_account_id}.dkr.ecr.${hongkong_region}.amazonaws.com/aws-for-fluent-bit
	else
		for region in ${classic_regions}; do
			publish_ssm ${region} ${classic_regions_account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit
		done
	fi
fi

# Verify SSM parameters
if [ "${1}" = "cicd-verify-ssm" ]; then
	if [ "${2}" = "us-gov-east-1" ] || [ "${2}" = "us-gov-west-1" ]; then
		for region in ${gov_regions}; do
			verify_ssm ${region}
		done
	elif [ "${2}" = "cn-north-1" ] || [ "${2}" = "cn-northwest-1" ]; then
		for region in ${cn_regions}; do
			verify_ssm ${region}
		done
	elif [ "${2}" = "${bahrain_region}" ]; then
		verify_ssm ${bahrain_region}
	elif [ "${2}" = "${hongkong_region}" ]; then
		verify_ssm ${hongkong_region}
	else
		for region in ${classic_regions}; do
			verify_ssm ${region}
		done
	fi
fi
