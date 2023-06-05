export TASK_DEF_FILE=fargate-task.json
export RUN_TASK_FILE=fargate-run-task.json
export TOTAL_SIZE_IN_MB="1000"
export TASK_REGION='us-west-2'
export LOG_REGION='us-east-1'
export THROUGHPUTS="
500
750
1000
1500
2000
3000
4000
5000
6000
7000
8000
9000
10000
"
export BUFFER_SIZES="
5m
10m
20m
30m
40m
"

export LOG_SIZES="
1
250
"

for SIZE_IN_KB in ${LOG_SIZES}; do
    export  SIZE_IN_KB=${SIZE_IN_KB}
    for MAX_BUFFER_SIZE in ${BUFFER_SIZES}; do
        export MAX_BUFFER_SIZE=${MAX_BUFFER_SIZE}
        export OUTPUT_FILE=fargate-"${MAX_BUFFER_SIZE}"-buffer-"${SIZE_IN_KB}"-log-size-output.txt
        export TASK_DEF_OUTPUT_FILE=fargate-"${MAX_BUFFER_SIZE}"-buffer-"${SIZE_IN_KB}"-log-size-taskdefs.txt
        for test_throughput in ${THROUGHPUTS}; do
            export THROUGHPUT=$test_throughput
            export TEST_NAME="$THROUGHPUT"KB_"${SIZE_IN_KB}"KB_AWSLOGS_"${MAX_BUFFER_SIZE}"_BUFFER_FARGATE_CROSS_REGION
            TASK_DEF=$(envsubst < "$TASK_DEF_FILE")
            echo "$TASK_DEF" >> $TASK_DEF_OUTPUT_FILE
            TASK_DEF_ARN=$(aws ecs register-task-definition --region ${TASK_REGION} --cli-input-json  "$TASK_DEF"  | jq '.taskDefinition.taskDefinitionArn')
            export TASK_DEF_ARN=$(echo "$TASK_DEF_ARN" | tr -d '"')
            echo "Running $THROUGHPUT $TEST_NAME $TASK_DEF_ARN"
            RUN_TASK=$(envsubst < "$RUN_TASK_FILE")
            aws ecs --region ${TASK_REGION} run-task --cli-input-json "$RUN_TASK" >> "$OUTPUT_FILE"
            echo "Started 5 tasks"
            sleep 300
            aws ecs --region ${TASK_REGION} run-task --cli-input-json "$RUN_TASK" >> "$OUTPUT_FILE"
            echo "Started 5 tasks"
            # can run more concurrent fargate tasks
            sleep 600
        done
    done
done