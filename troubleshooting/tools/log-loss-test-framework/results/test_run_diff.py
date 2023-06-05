import csv
import sys
import os
import statistics

# I should have made the buffer size an env var and printed in the result
# instead its part of the test name
TEST_NAMES_TO_BUFFER_SIZES = {
    'DEFAULT_BUFFER': 1,
    '2M_BUFFER': 2,
    '2MB_BUFFER': 2,
    '1m_BUFFER': 1,
    '2m_BUFFER': 2,
    '3m_BUFFER': 3,
    '4m_BUFFER': 4,
    '5m_BUFFER': 5,
    '6m_BUFFER': 6,
    '7m_BUFFER': 7,
    '8m_BUFFER': 8,
    '9m_BUFFER': 9,
    '10m_BUFFER': 10,
    '11m_BUFFER': 11,
    '12m_BUFFER': 12,
    '15m_BUFFER': 15,
    '20m_BUFFER': 20,
    '25m_BUFFER': 25,
    '30m_BUFFER': 30,
    '40m_BUFFER': 40,
    '50m_BUFFER': 50,
    '60m_BUFFER': 60,
    '75m_BUFFER': 75,
    '100m_BUFFER': 100,
    '150m_BUFFER': 150,
    '200m_BUFFER': 200,
}

def validate_test_run(test_run):
    if len(test_run) < 16:
        return 'len'
    if 'percent lost' not in test_run[1]:
        return 'percent lost'
    if 'number_lost' not in test_run[3]:
        return 'number_lost'
    if 'total_input_record' not in test_run[5]:
        return 'total_input_record'
    # early version of validator has this env var printed out with wrong name
    if 'SIZE_IN_MB' not in test_run[10] and 'SIZE_IN_KB' not in test_run[10]:
        return 'SIZE_IN_MB/SIZE_IN_KB'
    if 'THROUGHPUT_IN_KB' not in test_run[11]:
        return 'THROUGHPUT_IN_KB'
    if 'FARGATE' not in test_run[15] and 'EC2' not in test_run[15]:
        return 'LAUNCH_TYPE'
    return ""

def process_test_run(test_run):
    test_name = test_run[0].strip().split()[0]
    percent_lost = int(test_run[2].strip())
    number_lost = int(test_run[4].strip())
    success = False
    if number_lost == 0:
        success = True
    tmp = test_run[10].strip()
    split = tmp.split("=")
    log_size = split[1]
    tmp = test_run[11].strip()
    split = tmp.split("=")
    throughput = int(split[1])
    task_id = test_run[12].strip()
    cluster = test_run[13].strip()
    if '/' in cluster: # some output has cluster ARN, some just name, not sure why
        split = cluster.split("/")
        cluster = split[1]
    task_def = test_run[14].strip()
    launch_type = test_run[15].strip()
    region = test_run[16].strip()
    buffer_size = 0
    for pattern in TEST_NAMES_TO_BUFFER_SIZES:
        if pattern in test_name:
            buffer_size = TEST_NAMES_TO_BUFFER_SIZES[pattern]

    if buffer_size == 0:
        print("could not find buffer size in " + test_name)
        return None

    log_group = ""
    total_mb = ""
    grouped_data = test_run[9].strip()
    kv_data = grouped_data.split()
    for data in kv_data:
        kv = data.split('=')
        if kv[0] == 'group':
            log_group = kv[1]
        if kv[0] == 'TOTAL_SIZE_IN_MB':
            total_mb = kv[1]
    log_stream = os.environ.get('CW_LOG_STREAM_PREFIX', 'pre-testing-bug/logger/') + task_id

    return {
        'test_name': test_name,
        'success': success,
        'loss_%': percent_lost,
        'number_lost': number_lost,
        'log_size': log_size,
        'throughput': throughput,
        'cluster': cluster,
        'launch_type': launch_type,
        'buffer': buffer_size,
        'task_id': task_id,
        'task_def': task_def,
        'region': region,
        'log_group': log_group,
        'log_stream': log_stream,
        'total_mb': total_mb,
    }

first_set = {}
second_set = {}

if len(sys.argv) < 4:
    print("Usage: {acount ID} {original test runs} {re-validated test runs} \n{Performs a diff on two test run files")
    sys.exit(1)


with open(sys.argv[2]) as csv_file:
    csv_reader = csv.reader(csv_file, delimiter=',')
    line_count = 0
    for row in csv_reader:
        line_count += 1
        test_run = list(row)
        err = validate_test_run(test_run)
        if err != "":
            print("INVALID DATA: NOT FOUND: " + err + ",  --\n  " + ", ".join(test_run))
            continue

        data = process_test_run(test_run)
        if data == None:
            print("INVALID DATA: " + ", ".join(test_run))
            continue
            
        task_id = data['task_id']
        test_str = ", ".join(test_run)
        data['str'] = test_str
        
        first_set[task_id] = data


with open(sys.argv[3]) as csv_file:
    csv_reader = csv.reader(csv_file, delimiter=',')
    line_count = 0
    for row in csv_reader:
        line_count += 1
        test_run = list(row)
        err = validate_test_run(test_run)
        if err != "":
            print("INVALID DATA: NOT FOUND: " + err + ",  --\n  " + ", ".join(test_run))
            continue

        data = process_test_run(test_run)
        if data == None:
            print("INVALID DATA: " + ", ".join(test_run))
            continue
            
        task_id = data['task_id']
        test_str = ", ".join(test_run)
        data['str'] = test_str
        
        second_set[task_id] = data



re_validated = 0
unchanged = 0
total = len(first_set)

diff_event_counts = []
diff_streams = []

ACCOUNT_ID = sys.argv[1]

def log_stream_arn(region, group, stream):
    return 'arn:aws:logs:' + region + ':' + ACCOUNT_ID + ':log-group:' + group + ':log-stream:' + stream

# arn:aws:logs:region:account-id:log-group:log_group_name:log-stream:log-stream-name

for task_id in sorted(first_set.keys()):
    if task_id in second_set:
        first = first_set[task_id]
        second = second_set[task_id]
        if first['number_lost'] != second['number_lost']:
            re_validated += 1
            diff = first['number_lost'] - second['number_lost']
            arn = log_stream_arn(second['region'], second['log_group'], second['log_stream'])
            diff_event_counts.append(diff)
            diff_streams.append(arn)
        else:
            unchanged += 1

diff_event_counts.sort()

min = diff_event_counts[0]
max = diff_event_counts[-1]
mean = statistics.mean(diff_event_counts)
median = statistics.median(diff_event_counts)


print(diff_streams)
print('\n\n\n')
print(f'total streams: {total}\nconsistent: {unchanged}\nin-consistent: {re_validated}')
print('Stats on the different number of log events returned between original run and re-run:')
print(f'min: {min}\nmax: {max}\nmean: {mean}\nmedian: {median}')


