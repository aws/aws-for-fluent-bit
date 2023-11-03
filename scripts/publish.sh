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

# Environment configuration list (defaults included)
PRIMARY_ACCOUNT_ID="${AWS_FOR_FLUENT_BIT_PRIMARY_ACCOUNT_ID:-"906394416424"}"
PUBLIC_ECR_REGISTRY_URI="${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REGISTRY_URI:-"public.ecr.aws/aws-observability"}"
PUBLIC_ECR_REPOSITORY_NAME="${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_NAME:-"aws-for-fluent-bit"}"
PUBLIC_ECR_REGION="${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REGION:="us-east-1"}"
PUBLIC_ECR_URL="${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_URL:="https://public.ecr.aws/v2/aws-observability/aws-for-fluent-bit"}"
DOCKER_HUB_REPOSITORY_URI="${AWS_FOR_FLUENT_BIT_DOCKER_HUB_REPOSITORY_URI:="amazon/aws-for-fluent-bit"}"
DOCKER_HUB_SECRET_ID="${AWS_FOR_FLUENT_BIT_DOCKER_HUB_SECRET_ID:="com.amazonaws.dockerhub.aws-for-fluent-bit.credentials"}"
DOCKER_HUB_SECRET_REGION="${AWS_FOR_FLUENT_BIT_DOCKER_HUB_SECRET_REGION:="us-west-2"}"
PRIVATE_ECR_REGION="${AWS_FOR_FLUENT_BIT_PRIVATE_ECR_REGION:="us-west-2"}"
PRIVATE_ECR_ACCOUNT_ID="${AWS_FOR_FLUENT_BIT_PRIVATE_ECR_ACCOUNT_ID:="906394416424"}"

AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI="${PUBLIC_ECR_REGISTRY_URI}/${PUBLIC_ECR_REPOSITORY_NAME}"

scripts=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${scripts}"

IMAGE_SHA_MATCHED="FALSE"
AWS_FOR_FLUENT_BIT_VERSION=$(cat ../AWS_FOR_FLUENT_BIT_VERSION)
AWS_FOR_FLUENT_BIT_STABLE_VERSION=$(cat ../AWS_FOR_FLUENT_BIT_STABLE_VERSION)

PUBLISH_LATEST=$(cat ../linux.version | jq -r '.linux.latest')
echo "Publish Latest? ${PUBLISH_LATEST}"

# Problem: when we push a new version bump the version number in AWS_FOR_FLUENT_BIT_VERSION file changes
# but that version is not published immediately. Thus, sync tasks normally
# sync latest version found in DockerHub. But what if we want to release a non-latest version?
# then sync tasks need to know this. So we use the script to check for an already published version
# that's not latest

# this code currenly works because DockerHub returns the only last 100 tags and as of March 2023 we only have 64
# and it should keep working because dockerhub returns the latest tags first
public_ecr_image_tags_token=$(curl -s -S -k https://public.ecr.aws/token/ | jq -r '.token')
public_ecr_image_tags=$(curl -s -S -k -H "Authorization: Bearer $public_ecr_image_tags_token" "${PUBLIC_ECR_URL}/tags/list" | jq -r '.tags[]' | sort -rV)
tag_array=(`echo ${public_ecr_image_tags}`)
AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR=$(./get_latest_dockerhub_version.py linux latest ${tag_array[@]})

# If the AWS_FOR_FLUENT_BIT_VERSION is an older version which is already published to dockerhub
# and latest is set to false in linux.version, then we sync an older non-latest version.
# otherwise, normal behavior, sync latest version found in dockerhub
if [ "${PUBLISH_LATEST}" = "false" ]; then
	PUBLISH_NON_LATEST=$(./get_latest_dockerhub_version.py linux ${AWS_FOR_FLUENT_BIT_VERSION} ${tag_array[@]})
	if [ "${PUBLISH_NON_LATEST}" = "true" ]; then
		AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR=${AWS_FOR_FLUENT_BIT_VERSION}
	fi
fi

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

gamma_region="us-west-2"
gamma_account_id="626332813196"

ARCHITECTURES=("amd64" "arm64")

# This variable is used in the image tag
init="init"

docker_hub_login() {
	username="$(aws secretsmanager get-secret-value --secret-id $DOCKER_HUB_SECRET_ID --region $DOCKER_HUB_SECRET_REGION | jq -r '.SecretString | fromjson.username')"
	password="$(aws secretsmanager get-secret-value --secret-id $DOCKER_HUB_SECRET_ID --region $DOCKER_HUB_SECRET_REGION | jq -r '.SecretString | fromjson.password')"

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
		docker pull ${DOCKER_HUB_REPOSITORY_URI}:stable || echo "0"
		sha1=$(docker inspect --format='{{index .RepoDigests 0}}' ${1}:stable || echo "0")
		docker pull ${DOCKER_HUB_REPOSITORY_URI}:${AWS_FOR_FLUENT_BIT_STABLE_VERSION}
		sha2=$(docker inspect --format='{{index .RepoDigests 0}}' ${1}:${AWS_FOR_FLUENT_BIT_STABLE_VERSION})

		match_two_sha $sha1 $sha2

		if [ "$IMAGE_SHA_MATCHED" = "FALSE" ]; then
			create_manifest_list ${DOCKER_HUB_REPOSITORY_URI} "stable" ${AWS_FOR_FLUENT_BIT_STABLE_VERSION}
		fi
	else
		for arch in "${ARCHITECTURES[@]}"
		do
			docker tag ${1}:"$arch" ${DOCKER_HUB_REPOSITORY_URI}:"${arch}"-${AWS_FOR_FLUENT_BIT_VERSION}
			docker push ${DOCKER_HUB_REPOSITORY_URI}:"$arch"-${AWS_FOR_FLUENT_BIT_VERSION}

			docker tag ${1}:"$arch"-"debug" ${DOCKER_HUB_REPOSITORY_URI}:"${arch}"-"debug"-${AWS_FOR_FLUENT_BIT_VERSION}
			docker push ${DOCKER_HUB_REPOSITORY_URI}:"$arch"-"debug"-${AWS_FOR_FLUENT_BIT_VERSION}
			
			docker tag ${1}:"$init"-"$arch" ${DOCKER_HUB_REPOSITORY_URI}:"$init"-"${arch}"-${AWS_FOR_FLUENT_BIT_VERSION}
			docker push ${DOCKER_HUB_REPOSITORY_URI}:"$init"-"$arch"-${AWS_FOR_FLUENT_BIT_VERSION}

			docker tag ${1}:"$init"-"$arch"-"debug" ${DOCKER_HUB_REPOSITORY_URI}:"$init"-"${arch}"-"debug"-${AWS_FOR_FLUENT_BIT_VERSION}
			docker push ${DOCKER_HUB_REPOSITORY_URI}:"$init"-"$arch"-"debug"-${AWS_FOR_FLUENT_BIT_VERSION}

		done

		create_manifest_list ${DOCKER_HUB_REPOSITORY_URI} ${AWS_FOR_FLUENT_BIT_VERSION} ${AWS_FOR_FLUENT_BIT_VERSION}
		create_manifest_list ${DOCKER_HUB_REPOSITORY_URI} "debug"-${AWS_FOR_FLUENT_BIT_VERSION} debug-${AWS_FOR_FLUENT_BIT_VERSION}

		create_manifest_list_init ${DOCKER_HUB_REPOSITORY_URI} "$init"-${AWS_FOR_FLUENT_BIT_VERSION} ${AWS_FOR_FLUENT_BIT_VERSION}
		create_manifest_list_init ${DOCKER_HUB_REPOSITORY_URI} "$init"-"debug"-${AWS_FOR_FLUENT_BIT_VERSION} debug-${AWS_FOR_FLUENT_BIT_VERSION}

		if [ "${PUBLISH_LATEST}" = "true" ]; then
			create_manifest_list ${DOCKER_HUB_REPOSITORY_URI} "latest" ${AWS_FOR_FLUENT_BIT_VERSION}
			create_manifest_list ${DOCKER_HUB_REPOSITORY_URI} "debug-latest" debug-${AWS_FOR_FLUENT_BIT_VERSION}
			create_manifest_list_init ${DOCKER_HUB_REPOSITORY_URI} "init-latest" ${AWS_FOR_FLUENT_BIT_VERSION}
			create_manifest_list_init ${DOCKER_HUB_REPOSITORY_URI} "init-debug-latest" debug-${AWS_FOR_FLUENT_BIT_VERSION}
		fi
	fi
}

publish_to_public_ecr() {
	if [ $# -eq 2 ]; then
		aws ecr-public get-login-password --region ${PUBLIC_ECR_REGION} | docker login --username AWS --password-stdin ${PUBLIC_ECR_REGISTRY_URI}
		docker pull ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:stable || echo "0"
		sha1=$(docker inspect --format='{{index .RepoDigests 0}}' ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:stable || echo "0")
		docker pull ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:${AWS_FOR_FLUENT_BIT_STABLE_VERSION}
		sha2=$(docker inspect --format='{{index .RepoDigests 0}}' ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:${AWS_FOR_FLUENT_BIT_STABLE_VERSION})

		match_two_sha $sha1 $sha2

		if [ "$IMAGE_SHA_MATCHED" = "FALSE" ]; then
			aws ecr-public get-login-password --region ${PUBLIC_ECR_REGION} | docker login --username AWS --password-stdin ${PUBLIC_ECR_REGISTRY_URI}
			create_manifest_list ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI} "stable" ${AWS_FOR_FLUENT_BIT_STABLE_VERSION}
		fi
	else
		aws ecr-public get-login-password --region ${PUBLIC_ECR_REGION} | docker login --username AWS --password-stdin ${PUBLIC_ECR_REGISTRY_URI}

		for arch in "${ARCHITECTURES[@]}"
		do
			docker tag ${1}:"$arch" ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:"$arch"-${AWS_FOR_FLUENT_BIT_VERSION}
			docker push ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:"$arch"-${AWS_FOR_FLUENT_BIT_VERSION}

			docker tag ${1}:"$arch"-"debug" ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:"$arch"-"debug"-${AWS_FOR_FLUENT_BIT_VERSION}
			docker push ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:"$arch"-"debug"-${AWS_FOR_FLUENT_BIT_VERSION}

			docker tag ${1}:"$init"-"$arch" ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:"$init"-"$arch"-${AWS_FOR_FLUENT_BIT_VERSION}
			docker push ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:"$init"-"$arch"-${AWS_FOR_FLUENT_BIT_VERSION}

			docker tag ${1}:"$init"-"$arch"-"debug" ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:"$init"-"$arch"-"debug"-${AWS_FOR_FLUENT_BIT_VERSION}
			docker push ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:"$init"-"$arch"-"debug"-${AWS_FOR_FLUENT_BIT_VERSION}
		done

		create_manifest_list ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI} ${AWS_FOR_FLUENT_BIT_VERSION} ${AWS_FOR_FLUENT_BIT_VERSION}
		aws ecr-public get-login-password --region ${PUBLIC_ECR_REGION} | docker login --username AWS --password-stdin ${PUBLIC_ECR_REGISTRY_URI}
		create_manifest_list ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI} "debug"-${AWS_FOR_FLUENT_BIT_VERSION} debug-${AWS_FOR_FLUENT_BIT_VERSION}
		
		create_manifest_list_init ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI} "$init"-${AWS_FOR_FLUENT_BIT_VERSION} ${AWS_FOR_FLUENT_BIT_VERSION}
		aws ecr-public get-login-password --region ${PUBLIC_ECR_REGION} | docker login --username AWS --password-stdin ${PUBLIC_ECR_REGISTRY_URI}
		create_manifest_list_init ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI} "$init"-"debug"-${AWS_FOR_FLUENT_BIT_VERSION} debug-${AWS_FOR_FLUENT_BIT_VERSION}

		if [ "${PUBLISH_LATEST}" = "true" ]; then
			create_manifest_list ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI} "latest" ${AWS_FOR_FLUENT_BIT_VERSION}
			aws ecr-public get-login-password --region ${PUBLIC_ECR_REGION} | docker login --username AWS --password-stdin ${PUBLIC_ECR_REGISTRY_URI}
			create_manifest_list ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI} "debug-latest" debug-${AWS_FOR_FLUENT_BIT_VERSION}

			create_manifest_list_init ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI} "init-latest" ${AWS_FOR_FLUENT_BIT_VERSION}
			aws ecr-public get-login-password --region ${PUBLIC_ECR_REGION} | docker login --username AWS --password-stdin ${PUBLIC_ECR_REGISTRY_URI}
			create_manifest_list_init ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI} "init-debug-latest" debug-${AWS_FOR_FLUENT_BIT_VERSION}
		fi
	fi
}

publish_ssm() {
	# This optional parameter indicates if we should publish stable (defaults to false)
	if [ ${4:-false} = true ]; then
		aws ssm put-parameter --name /aws/service/aws-for-fluent-bit/stable --overwrite \
			--description 'Regional Amazon ECR Image URI for the latest stable AWS for Fluent Bit Docker Image' \
			--type String --region ${1} --value ${2}:${3}
	else
		aws ssm put-parameter --name /aws/service/aws-for-fluent-bit/${3} --overwrite \
			--description 'Regional Amazon ECR Image URI for the latest AWS for Fluent Bit Docker Image' \
			--type String --region ${1} --value ${2}:${3}

		if [ "${PUBLISH_LATEST}" = "true" ]; then
			aws ssm put-parameter --name /aws/service/aws-for-fluent-bit/latest --overwrite \
				--description 'Regional Amazon ECR Image URI for the latest AWS for Fluent Bit Docker Image' \
				--type String --region ${1} --value ${2}:latest
		fi
		
		aws ssm put-parameter --name /aws/service/aws-for-fluent-bit/"$init"-${3} --overwrite \
			--description 'Regional Amazon ECR Image URI for the "$init"-latest AWS for Fluent Bit Docker Image' \
			--type String --region ${1} --value ${2}:"$init"-${3}

		if [ "${PUBLISH_LATEST}" = "true" ]; then
			aws ssm put-parameter --name /aws/service/aws-for-fluent-bit/"$init"-latest --overwrite \
				--description 'Regional Amazon ECR Image URI for the "$init"-latest AWS for Fluent Bit Docker Image' \
				--type String --region ${1} --value ${2}:"$init"-latest
		fi
	fi
}

rollback_ssm() {
	aws ssm delete-parameter --name /aws/service/aws-for-fluent-bit/${AWS_FOR_FLUENT_BIT_VERSION} --region ${1}

	aws ssm delete-parameter --name /aws/service/aws-for-fluent-bit/"$init"-${AWS_FOR_FLUENT_BIT_VERSION} --region ${1}
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

	if [ "${2}" != "stable" ]; then 
		repo_uri_init=$(aws ssm get-parameter --name /aws/service/aws-for-fluent-bit/"$init"-${2} --region ${1} --query 'Parameter.Value')
		IFS='.' read -r -a array <<<"$repo_uri_init"
		region="${array[3]}"
		if [ "${1}" != "${region}" ]; then
			echo "${1}: Region found in repo URI does not match SSM Parameter region: ${repo_uri}"
			exit 1
		fi
		# remove leading and trailing quotes from repo_uri
		repo_uri_init=$(sed -e 's/^"//' -e 's/"$//' <<<"$repo_uri")
		docker pull $repo_uri_init
	fi
}

sync_public_and_repo() {
	region=${1}
	account_id=${2}
	endpoint=${3}
	tag=${4}

	docker pull ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:${tag}
	sha1=$(docker inspect --format='{{index .RepoDigests 0}}' ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:${tag})
	aws ecr get-login-password --region ${region}| docker login --username AWS --password-stdin ${account_id}.dkr.ecr.${region}.${endpoint}
	repoList=$(aws ecr describe-repositories --region ${region})
	repoName=$(echo $repoList | jq .repositories[0].repositoryName)
	if [ "$repoName" = '"aws-for-fluent-bit"' ]; then
		tagCount=$(aws ecr list-images  --repository-name aws-for-fluent-bit --region ${region} | jq -r '.imageIds[].imageTag' | grep -c ${tag} || echo "0")
		if [ "$tagCount" = '1' ]; then
			docker pull ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${tag}
			sha2=$(docker inspect --format='{{index .RepoDigests 0}}' ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${tag})
		else
			sha2='repo_not_found'
		fi
	else
		sha2='repo_not_found'
	fi

	match_two_sha $sha1 $sha2

	if [ "$IMAGE_SHA_MATCHED" = "FALSE" ]; then
		aws ecr create-repository --repository-name aws-for-fluent-bit --image-scanning-configuration scanOnPush=true --region ${region}  || true
		push_image_ecr ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:${tag} \
			${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${tag}
	fi
}

sync_ssm() {
	namespace_path=${1}
	region=${2}
	repo=${3}
	tag=${4}

	# Check the namespace_path looking for stable at the end, if the string were too short it would return an empty string
	is_stable=false
	if [ "${namespace_path:(-6)}" = "stable" ]; then
		is_stable=true
	fi

	invalid_parameter=
	should_prepare=false
	# Check to see if namespace is prepared, once a parameter is put into namespace requests should not fail
	if ! ssm_parameters=$(aws ssm get-parameters --names ${namespace_path} --region ${region}); then
		should_prepare=true
	else
		invalid_parameter=$(echo $ssm_parameters | jq .InvalidParameters[0])
	fi

	if [ $should_prepare = true ] || [ "$invalid_parameter" != 'null' ]; then
		publish_ssm ${region} ${repo} ${tag} ${is_stable}
	fi
}

sync_image_version() {
	region=${1}
	account_id=${2}

	endpoint='amazonaws.com'
	if [ "${1}" = "cn-north-1" ] || [ "${1}" = "cn-northwest-1" ]; then
		endpoint=${endpoint}.cn
	fi
	
	for arch in "${ARCHITECTURES[@]}"
	do
		aws ecr-public get-login-password --region ${PUBLIC_ECR_REGION} | docker login --username AWS --password-stdin ${PUBLIC_ECR_REGISTRY_URI} || echo "0"
		sync_public_and_repo ${region} ${account_id} ${endpoint} "${arch}-${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}"

		sync_public_and_repo ${region} ${account_id} ${endpoint} "${arch}-debug-${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}"

		sync_public_and_repo ${region} ${account_id} ${endpoint} "${init}-${arch}-${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}"

		sync_public_and_repo ${region} ${account_id} ${endpoint} "${init}-${arch}-debug-${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}"

		sync_public_and_repo ${region} ${account_id} ${endpoint} "${arch}-${AWS_FOR_FLUENT_BIT_STABLE_VERSION}"
	done

	if [ "${account_id}" != "${classic_regions_account_id}" ]; then
		create_manifest_list ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR} ${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}
		create_manifest_list ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit "debug"-${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR} debug-${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}

		create_manifest_list_init ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit "$init"-${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR} ${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}
		create_manifest_list_init ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit "$init"-"debug"-${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR} debug-${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}
		if [ "${PUBLISH_LATEST}" = "true" ]; then
			create_manifest_list ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit "latest" ${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}
			create_manifest_list ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit "debug-latest" debug-${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}

			create_manifest_list_init ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit "init-latest" ${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}
			create_manifest_list_init ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit "init-debug-latest" debug-${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}
		fi
	fi

	if [ "${AWS_FOR_FLUENT_BIT_STABLE_VERSION}" != "${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}" ]; then
		create_manifest_list ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_STABLE_VERSION} ${AWS_FOR_FLUENT_BIT_STABLE_VERSION}
	fi

	create_manifest_list ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit "stable" ${AWS_FOR_FLUENT_BIT_STABLE_VERSION} || echo "0"

	make_repo_public ${region}

	sync_ssm "/aws/service/aws-for-fluent-bit/${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}" ${region} ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}
	sync_ssm "/aws/service/aws-for-fluent-bit/stable" ${region} ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_STABLE_VERSION}

	stable_uri=$(aws ssm get-parameters --names /aws/service/aws-for-fluent-bit/stable --region ${region} --query 'Parameters[0].Value')
	stable_uri=$(sed -e 's/^"//' -e 's/"$//' <<<"$stable_uri")

	if [ "$stable_uri" != "${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_STABLE_VERSION}" ]; then
		publish_ssm ${region} ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_STABLE_VERSION} true
	fi
}

verify_ssm() {
	is_sync_task=${2:-false}

	endpoint='amazonaws.com'
	
	if [ "${1}" = "cn-north-1" ] || [ "${1}" = "cn-northwest-1" ]; then
		endpoint=${endpoint}.cn
	fi
	aws ecr get-login-password --region ${1} | docker login --username AWS --password-stdin ${3}.dkr.ecr.${1}.${endpoint}

	if [ "${PUBLISH_LATEST}" = "true" ]; then
		check_parameter ${1} latest
	fi

	if [ "${is_sync_task}" = "true" ]; then
		check_parameter ${1} ${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}
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

create_manifest_list_init() {

	export DOCKER_CLI_EXPERIMENTAL=enabled
	tag=${2}
	version=${3}

	# TODO: Add a way to automatically generate arch images in manifest
	docker manifest create ${1}:${tag} ${1}:"$init"-arm64-${version} ${1}:"$init"-amd64-${version}

	for arch in "${ARCHITECTURES[@]}"
	do
		docker manifest annotate --arch "$arch" ${1}:${tag} ${1}:"$init"-"$arch"-${version}
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

		push_image_ecr ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:"$arch"-"debug" \
			${account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit:"$arch"-"debug"-${AWS_FOR_FLUENT_BIT_VERSION}

		push_image_ecr ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:"$init"-"$arch" \
			${account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit:"$init"-"$arch"-${AWS_FOR_FLUENT_BIT_VERSION}

		push_image_ecr ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/amazon/aws-for-fluent-bit-test:"$init"-"$arch"-"debug" \
			${account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit:"$init"-"$arch"-"debug"-${AWS_FOR_FLUENT_BIT_VERSION}
	done

	create_manifest_list ${account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION} ${AWS_FOR_FLUENT_BIT_VERSION}
	create_manifest_list ${account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit "debug"-${AWS_FOR_FLUENT_BIT_VERSION} debug-${AWS_FOR_FLUENT_BIT_VERSION}
	create_manifest_list_init ${account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit "$init"-${AWS_FOR_FLUENT_BIT_VERSION} ${AWS_FOR_FLUENT_BIT_VERSION}
	create_manifest_list_init ${account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit "$init"-"debug"-${AWS_FOR_FLUENT_BIT_VERSION} debug-${AWS_FOR_FLUENT_BIT_VERSION}

	if [ "${PUBLISH_LATEST}" = "true" ]; then
		create_manifest_list ${account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit "latest" ${AWS_FOR_FLUENT_BIT_VERSION}
		create_manifest_list ${account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit "debug-latest" debug-${AWS_FOR_FLUENT_BIT_VERSION}
		create_manifest_list_init ${account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit "init-latest" ${AWS_FOR_FLUENT_BIT_VERSION}
		create_manifest_list_init ${account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit "init-debug-latest" debug-${AWS_FOR_FLUENT_BIT_VERSION}
	fi 

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

		docker pull ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}
		sha1=$(docker inspect --format='{{index .RepoDigests 0}}' ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR})

		docker pull ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:"$init"-${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}
		sha1_init=$(docker inspect --format='{{index .RepoDigests 0}}' ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:"$init"-${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR})

		# verify version number tag against public ECR
		docker pull ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}
		sha2=$(docker inspect --format='{{index .RepoDigests 0}}' ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR})

		verify_sha $sha1 $sha2

		docker pull ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:init-${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR}
		sha2_init=$(docker inspect --format='{{index .RepoDigests 0}}' ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:init-${AWS_FOR_FLUENT_BIT_VERSION_PUBLIC_ECR})

		verify_sha $sha1_init $sha2_init
	else
		docker pull ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION}
		sha1=$(docker inspect --format='{{index .RepoDigests 0}}' ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:${AWS_FOR_FLUENT_BIT_VERSION})

		docker pull ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:"$init"-${AWS_FOR_FLUENT_BIT_VERSION}
		sha1_init=$(docker inspect --format='{{index .RepoDigests 0}}' ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:"$init"-${AWS_FOR_FLUENT_BIT_VERSION})
	fi

	# in main pipeline when publishing a non-latest release
	# we can't verify the SHA against any other tag
	# only verification is the above steps to pull the image
	if [ "${PUBLISH_LATEST}" = "true" ]; then
	    # Also validate version number tag against latest tag
		docker pull ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:latest
		sha2=$(docker inspect --format='{{index .RepoDigests 0}}' ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:latest)

		verify_sha $sha1 $sha2

		docker pull ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:"$init"-latest
		sha2_init=$(docker inspect --format='{{index .RepoDigests 0}}' ${account_id}.dkr.ecr.${region}.${endpoint}/aws-for-fluent-bit:"$init"-latest)
		
		verify_sha $sha1_init $sha2_init
	fi 
}

check_image_version() {
	export DOCKER_CLI_EXPERIMENTAL=enabled
	EXIT_CODE=0

	docker_hub_login
	
	# check if we can get the image information in dockerhub; if yes, the exit status should be 0
	docker manifest inspect ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:${1} > /dev/null || EXIT_CODE=$?
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

	tagCount=$(aws ecr list-images  --repository-name ${repo_uri} --region ${region} | jq -r '.imageIds[].imageTag' | grep -c ${tag} || echo "0")
	if [ "$tagCount" = '1' ]; then
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
	if [ $# -eq 1 ] || [ "${PUBLISH_LATEST}" = "false" ]; then
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

		docker pull amazon/aws-for-fluent-bit:"$init"-latest
		sha1_init=$(docker inspect --format='{{index .RepoDigests 0}}' amazon/aws-for-fluent-bit:"$init"-latest)
		docker pull amazon/aws-for-fluent-bit:"$init"-${AWS_FOR_FLUENT_BIT_VERSION}
		sha2_init=$(docker inspect --format='{{index .RepoDigests 0}}' amazon/aws-for-fluent-bit:"$init"-${AWS_FOR_FLUENT_BIT_VERSION})
		verify_sha $sha1_init $sha2_init
	fi
}

verify_public_ecr() {
	aws ecr-public get-login-password --region ${PUBLIC_ECR_REGION} | docker login --username AWS --password-stdin ${PUBLIC_ECR_REGISTRY_URI} || echo "0"

	# Verify the image with stable tag
	if [ $# -eq 1 ] || [ "${PUBLISH_LATEST}" = "false" ]; then
		# Get the image SHA's
		docker pull ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:stable
		sha1=$(docker inspect --format='{{index .RepoDigests 0}}' ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:stable)
		docker pull ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:${AWS_FOR_FLUENT_BIT_STABLE_VERSION}
		sha2=$(docker inspect --format='{{index .RepoDigests 0}}' ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:${AWS_FOR_FLUENT_BIT_STABLE_VERSION})

		verify_sha $sha1 $sha2
	else
		# Get the image SHA's
		docker pull ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:latest
		sha1=$(docker inspect --format='{{index .RepoDigests 0}}' ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:latest)
		docker pull ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:${AWS_FOR_FLUENT_BIT_VERSION}
		sha2=$(docker inspect --format='{{index .RepoDigests 0}}' ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:${AWS_FOR_FLUENT_BIT_VERSION})

		verify_sha $sha1 $sha2

		docker pull ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:"$init"-latest
		sha1_init=$(docker inspect --format='{{index .RepoDigests 0}}' ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:"$init"-latest)
		docker pull ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:"$init"-${AWS_FOR_FLUENT_BIT_VERSION}
		sha2_init=$(docker inspect --format='{{index .RepoDigests 0}}' ${AWS_FOR_FLUENT_BIT_PUBLIC_ECR_REPOSITORY_URI}:"$init"-${AWS_FOR_FLUENT_BIT_VERSION})

		verify_sha $sha1_init $sha2_init
	fi
}

verify_sha() {
	_sha1=${1}
	_sha2=${2}

	match_two_sha $_sha1 $_sha2

	if [ "$IMAGE_SHA_MATCHED" = "TRUE" ]; then
		echo '[Publish Verification] Successfull'
		IMAGE_SHA_MATCHED="FALSE"
	else
		echo '[Publish Verification] Failed'
		exit 1
	fi
}

match_two_sha() {
	_sha1=${1}
	_sha2=${2}

	# Get the last 64 chars of the SHA string
	last64_1=$(echo $_sha1 | egrep -o '.{1,64}$')
	last64_2=$(echo $_sha2 | egrep -o '.{1,64}$')

	if [ "$last64_1" = "$last64_2" ]; then
		IMAGE_SHA_MATCHED="TRUE"
	else
		IMAGE_SHA_MATCHED="FALSE"
	fi
}

# Following scripts will be called only from the CI/CD pipeline

# Publish using the CI/CD pipeline
if [ "${1}" = "cicd-publish" ]; then
	# Sentinel check we are in the primary distribution account
    if [ "${AWS_ACCOUNT}" = "${PRIMARY_ACCOUNT_ID}" ]; then
		if [ "${2}" = "dockerhub" ]; then
			publish_to_docker_hub amazon/aws-for-fluent-bit
		elif [ "${2}" = "public-ecr" ]; then
			publish_to_public_ecr amazon/aws-for-fluent-bit
		elif [ "${2}" = "private-ecr" ]; then
			publish_ecr ${PRIVATE_ECR_REGION} ${PRIMARY_ACCOUNT_ID}
		
		elif [ "${2}" = "dockerhub-stable" ]; then
			publish_to_docker_hub amazon/aws-for-fluent-bit stable
		elif [ "${2}" = "public-ecr-stable" ]; then
			publish_to_public_ecr amazon/aws-for-fluent-bit stable
		elif [ "${2}" = "private-ecr-stable" ]; then
			# Implementation sync_image_version includes
			#   1) Sync Public ECR to Private ECR (todo: break up function and remove - leave for now)
			#   2) Update stable from GitHub repository stable file
			sync_image_version ${PRIVATE_ECR_REGION} ${PRIMARY_ACCOUNT_ID}
		fi
	fi
fi

# Replicate to replica accounts using the CI/CD pipeline
if [ "${1}" = "cicd-replicate" ]; then
	# Sentinel check we are in a replica distribution account
	if [ "${AWS_ACCOUNT}" != "${PRIMARY_ACCOUNT_ID}" ]; then
		if [ "${2}" = "us-gov-east-1" ] || [ "${2}" = "us-gov-west-1" ]; then
			for region in ${gov_regions}; do
				sync_image_version ${region} ${gov_regions_account_id}
			done
		elif [ "${2}" = "cn-north-1" ] || [ "${2}" = "cn-northwest-1" ]; then
			for region in ${cn_regions}; do
				sync_image_version ${region} ${cn_regions_account_id}
			done
		else
			sync_image_version ${2} ${AWS_ACCOUNT}
		fi
	fi
fi

# Verify publish using CI/CD pipeline
# To be used after initial release or stable update
if [ "${1}" = "cicd-verify-publish" ]; then
	# Sentinel check in primary account 
	if [ "${AWS_ACCOUNT}" = "${PRIMARY_AWS_ACCOUNT}" ]; then
		# Primary account: verify after pipeline release
		if [ "${2}" = "dockerhub" ]; then
			verify_dockerhub
		elif [ "${2}" = "public-ecr" ]; then
			verify_public_ecr
		elif [ "${2}" = "private-ecr"]; then
			verify_ecr ${PRIVATE_ECR_REGION} ${PRIMARY_ACCOUNT_ID}
			
		# Primary account: verify after sync task stable update release
		elif [ "${2}" = "dockerhub-stable" ]; then
			verify_dockerhub stable
		elif [ "${2}" = "public-ecr-stable" ]; then
			verify_public_ecr stable
		elif [ "${2}" = "private-ecr-stable" ]; then
			verify_ecr ${PRIVATE_ECR_REGION} ${PRIMARY_ACCOUNT_ID} true
		fi
	fi
fi

# Verify replicate using CI/CD pipeline
# To be used after sync task
if [ "${1}" = "cicd-verify-replicate"]
	# Sentinel check we are in a replica distribution account
	if [ "${AWS_ACCOUNT}" != "${PRIMARY_ACCOUNT_ID}" ]; then
		if [ "${2}" = "us-gov-east-1" ] || [ "${2}" = "us-gov-west-1" ]; then
			for region in ${gov_regions}; do
				verify_ecr ${region} ${gov_regions_account_id} true
			done
		elif [ "${2}" = "cn-north-1" ] || [ "${2}" = "cn-northwest-1" ]; then
			for region in ${cn_regions}; do
				verify_ecr ${region} ${cn_regions_account_id} true
			done
		else
			verify_ecr ${2} ${AWS_ACCOUNT} true
		fi
	fi
fi

# Publish SSM parameters
# To be used only by the primary account on release
if [ "${1}" = "cicd-publish-ssm" ]; then
	# Sentinel check in primary account 
	if [ "${AWS_ACCOUNT}" = "${PRIMARY_AWS_ACCOUNT}" ]; then
		for region in ${classic_regions}; do
			publish_ssm ${region} ${classic_regions_account_id}.dkr.ecr.${region}.amazonaws.com/aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_VERSION}
		done
	fi
fi

# Verify SSM parameters
if [ "${1}" = "cicd-verify-ssm" ]; then

	is_sync_task=${3:-false}

	# Primary account: supports verification for sync task ssm update and after publish
	if [ "${AWS_ACCOUNT}" = "${PRIMARY_AWS_ACCOUNT}" ]; then
		for region in ${classic_regions}; do
			verify_ssm ${region} ${is_sync_task} ${classic_regions_account_id}
		done

	# Replica account: supports verification only after sync task ssm update
	else
		if [ "${2}" = "us-gov-east-1" ] || [ "${2}" = "us-gov-west-1" ]; then
			for region in ${gov_regions}; do
				verify_ssm ${region} true ${gov_regions_account_id}
			done
		elif [ "${2}" = "cn-north-1" ] || [ "${2}" = "cn-northwest-1" ]; then
			for region in ${cn_regions}; do
				verify_ssm ${region} true ${cn_regions_account_id}
			done
		else
			verify_ssm ${2} true ${AWS_ACCOUNT}
		fi
	fi
fi

if [ "${1}" = "cicd-verify-ecr-image-scan" ]; then
	verify_ecr_image_scan ${2} ${3} ${4}
fi

if [ "${1}" = "cicd-check-image-version" ]; then
	check_image_version ${AWS_FOR_FLUENT_BIT_VERSION} 
fi