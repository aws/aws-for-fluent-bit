#!/bin/bash

usage() {
    echo "Requires: AWS CLI, jq. Run with creds for the account."
    echo "Queries can take 1+ hours to complete. Run this command some time after exec_query.sh."
    echo "This script copies the query result from the S3 output bucket and prints & downloads it locally"
    echo "Usage: bash $0 {AWS Region} {Athena Query Execution ID}"
    echo "-----Examples-----"
    echo "bash $0 us-west-2 f5125589-0003-49bf-a8f4-25dd9407aef2"
    exit 1;
}

get_results() {
    query_state=$(aws athena get-query-execution --query-execution-id ${QUERY_ID} --region ${AWS_REGION} | jq '.QueryExecution.Status.State' | tr -d '"')
    if [[ "${query_state}" == "SUCCEEDED" ]];
    then
        s3_uri=$(aws athena get-query-execution --query-execution-id ${QUERY_ID} --region ${AWS_REGION} | jq '.QueryExecution.ResultConfiguration.OutputLocation' | tr -d '"')
        aws s3 cp ${s3_uri} ${QUERY_ID}_results.txt
        cat ${QUERY_ID}_results.txt
    elif [[ "${query_state}" == "FAILED" ]];
    then
        echo "Query state is |FAILED|"
        echo ""
        query=$(aws athena get-query-execution --query-execution-id ${QUERY_ID} --region ${AWS_REGION} | jq '.QueryExecution.Query')
        echo ${query}
        echo ""
        error=$(aws athena get-query-execution --query-execution-id ${QUERY_ID} --region ${AWS_REGION} | jq '.QueryExecution.Status')
        echo ${error}
        echo ""
    else
        echo "Query state is |${query_state}|. Wait for state to be SUCCEEDED or re-run."
        echo ""
    fi;
}

export AWS_REGION=$1
if [ -z "${AWS_REGION}" ];
then
    usage
fi

export QUERY_ID=$2
if [ -z "${QUERY_ID}" ];
then
    usage
fi


get_results