#!/bin/bash

VERSION=$1
if [ -z "$VERSION" ]; then
    echo "Usage $0 <version>"
    echo "Example: $0 2.31.11 "
    exit 1;
fi

image_shas=$(aws ecr describe-images --registry-id 906394416424 --repository-name aws-for-fluent-bit --region us-west-2 --image-ids imageTag=arm64-${VERSION} imageTag=amd64-${VERSION} imageTag=init-arm64-${VERSION} imageTag=init-amd64-${VERSION} imageTag=${VERSION}-ltsc2019 imageTag=${VERSION}-ltsc2022 | jq -r '.imageDetails[] | objects | .imageDigest')

image_sha_array=($image_shas)

echo "Paste below query into Athena console and replace eventTime with desired data range"
echo "This can be used to obtain 'private' ECR download count"
echo "The query is for classic regions but can be used in other regions by changing the table name to 'cloudtrail_fluentbit'"
echo "-------"
echo ""
echo "
SELECT COUNT(*) as call_count
FROM cloudtrail_fluentbitimage
WHERE
    eventsource = 'ecr.amazonaws.com' AND
    eventname in ('GetDownloadUrlForLayer', 'BatchGetImage') AND
    eventTime > 'YYYY-MM-DDT00:00:00Z' AND
    eventTime < 'YYYY-MM-DDT00:00:00Z' AND (
      requestparameters like '%"imageTag":"${VERSION}"%' OR
      requestparameters like '%"imageTag":"amd64-${VERSION}"%' OR
      requestparameters like '%"imageTag":"arm64-${VERSION}"%' OR
      requestparameters like '%"imageTag":"init-${VERSION}"%' OR
      requestparameters like '%"imageTag":"init-amd64-${VERSION}"%' OR
      requestparameters like '%"imageTag":"init-arm64-${VERSION}"%' OR
      requestparameters like '%"imageTag":"${VERSION}-windowsservercore"%' OR
      requestparameters like '%"imageTag":"${VERSION}-ltsc2019"%' OR
      requestparameters like '%"imageTag":"${VERSION}-ltsc2022"%' OR
      requestparameters like '%${image_sha_array[0]}%' OR
      requestparameters like '%${image_sha_array[1]}%' OR
      requestparameters like '%${image_sha_array[2]}%' OR
      requestparameters like '%${image_sha_array[3]}%' OR
      requestparameters like '%${image_sha_array[4]}%' OR
      requestparameters like '%${image_sha_array[5]}%'
    )
"

