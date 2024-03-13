#!/bin/bash

get_all_download_query() {
    export QUERY="
SELECT COUNT(*) as call_count
FROM ${TABLE_NAME}
WHERE
    eventsource = 'ecr.amazonaws.com' AND
    eventname in ('GetDownloadUrlForLayer', 'BatchGetImage') AND
    eventTime > '${START_YEAR}-${START}-01T00:00:00Z' AND
    eventTime < '${END_YEAR}-${END}-01T00:00:00Z'
"
}

get_version_download_query() {
    scripts=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    export QUERY=$(bash "${scripts}/version_download_query.sh" ${VERSION} -s)
}

usage() {
    echo "Requires: AWS CLI, jq. Run with creds for the account."
    echo "Usage: bash $0 {all | version number} {AWS Region} {AWS Account ID} {Start Year} {Target/first Month} {End Year} {Next/excluded Month}"
    echo "If you want November's downloads, then Target Month=11, Next Month=12"
    echo "Outputs the Athena Query Execution ID, which can be used with get_results.sh"
    echo "-----Examples: Query total image downloads for a month-----"
    echo "CLASSIC: bash exec_query.sh all us-west-2 906394416424 2023 11 2023 12"
    echo "BAH: bash $0 all me-south-1 741863432321 2023 12 2024 01"
    echo "HKG: bash $0 all ap-east-1 449074385750 2024 01 2024 02"
    echo "MXP: bash $0 all eu-south-1 960320637246 2023 11 2023 12"
    echo "CPT: bash $0 all af-south-1 928143927712 2023 01 2023 02"
    echo "USGOV: bash $0 all us-gov-west-1 161423150738 2023 11 2023 12"
    echo "-----Examples: Query total image downloads for specific version in a month-----"
    echo "bash exec_query.sh 2.28.4 us-west-2 906394416424 2023 11 12"
    echo "bash exec_query.sh 2.31.12.20230727 us-west-2 906394416424 2023 11 2023 12"
    exit 1;
}

exec_query() {
    export S3_LOC="s3://aws-athena-query-results-${ACCT_ID}-${AWS_REGION}"
    echo ""
    echo "Athena Query Execution ID:"
    aws athena start-query-execution \
        --region "${AWS_REGION}" \
        --query-string "${QUERY}" \
        --query-execution-context Database="${DB_NAME}",Catalog="${CATALOG}" \
        --result-configuration OutputLocation="${S3_LOC}" \
        --output text
    echo ""
}

export VERSION=$1
if [ -z "${VERSION}" ];
then
    usage
fi

export AWS_REGION=$2
if [ -z "${AWS_REGION}" ];
then
    usage
fi

# Run script with creds for the account
export ACCT_ID=$3
if [ -z "${ACCT_ID}" ];
then
    usage
fi

export START_YEAR=$4
if [ -z "${START_YEAR}" ];
then
    usage
fi

export START=$5
if [ -z "${START}" ];
then
    usage
fi

export END_YEAR=$6
if [ -z "${END_YEAR}" ];
then
    usage
fi

export END=$7
if [ -z "${END}" ];
then
    usage
fi

export CATALOG="AwsDataCatalog"
export TABLE_NAME="cloudtrail_fluentbit"

# DB name and table name are not consistent across regions
if [ "${ACCT_ID}" = "906394416424" ]; then
    export DB_NAME="cloudtraillogs"
    export TABLE_NAME="cloudtrail_fluentbitimage"
elif [ "${ACCT_ID}" = "928143927712" ]; then
    export DB_NAME="cloudtraillogs"
elif [ "${ACCT_ID}" = "161423150738" ]; then
    export DB_NAME="cloudtraillogs"
    export TABLE_NAME="cloudtrail_fluentbitimage"
else
    export DB_NAME="default"
fi

if [ "${VERSION}" = "all" ]; then
    get_all_download_query
    exec_query
else
    get_version_download_query
    exec_query
fi
