export TASK_DEF_FILE=task-def.json
export RUN_TASK_FILE=ec2-run-task.json
export TOTAL_SIZE_IN_MB="1000"
# throughput unit is KB/s
export THROUGHPUTS="
1000
2000
3000
4000
4500
5000
6000
7000
8000
9000
10000
12000
"
# buffer size unit is megabyte
export BUFFER_SIZES="
1m
2m
4m
6m
8m
12m
"

export LOG_SIZES="
1
250
"

for SIZE_IN_KB in ${LOG_SIZES}; do
    export  SIZE_IN_KB=${SIZE_IN_KB}
    for MAX_BUFFER_SIZE in ${BUFFER_SIZES}; do
        export MAX_BUFFER_SIZE=${MAX_BUFFER_SIZE}
        export OUTPUT_FILE=ec2-"${MAX_BUFFER_SIZE}"-buffer-"${SIZE_IN_KB}"-log-size-output.txt
        export TASK_DEF_OUTPUT_FILE=ec2-"${MAX_BUFFER_SIZE}"-buffer-"${SIZE_IN_KB}"-log-size-taskdefs.txt
        for test_throughput in ${THROUGHPUTS}; do
            export THROUGHPUT=$test_throughput
            export TEST_NAME="$THROUGHPUT"KB_"${SIZE_IN_KB}"KB_AWSLOGS_PATCHED_"${MAX_BUFFER_SIZE}"_BUFFER_EC2
            TASK_DEF=$(envsubst < "$TASK_DEF_FILE")
            echo "$TASK_DEF" >> $TASK_DEF_OUTPUT_FILE
            TASK_DEF_ARN=$(aws ecs register-task-definition --region us-west-2 --cli-input-json  "$TASK_DEF"  | jq '.taskDefinition.taskDefinitionArn')
            export TASK_DEF_ARN=$(echo "$TASK_DEF_ARN" | tr -d '"')
            echo "Running $THROUGHPUT $TEST_NAME $TASK_DEF_ARN"
            RUN_TASK=$(envsubst < "$RUN_TASK_FILE")
            aws ecs --region us-west-2 run-task --cli-input-json "$RUN_TASK" >> "$OUTPUT_FILE"
            echo "Started 10 tasks"
            sleep 100
            aws ecs --region us-west-2 run-task --cli-input-json "$RUN_TASK" >> "$OUTPUT_FILE"
            echo "Started 10 tasks"
            sleep 1000
        done
    done
done