import sys
import matplotlib.pyplot as plt
import os

# the final utilized version of the validator can output histograms
# with a full list of all IDs lost



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

def process_test_run(test_run):
    test_name = test_run[0].strip().split()[0]
    percent_lost = int(test_run[2].strip())
    number_lost = int(test_run[4].strip())
    total_input_record = test_run[6].strip()
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
        'total_input_record': total_input_record,
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

# set this to the set of fields from above that you want to aggregate data on
aggregate_on = ['total_input_record', 'launch_type']

# aggregate data into histograms based on fields extracted from the summary
def aggregation_key(data):
    key = ""
    for field in aggregate_on:
        val = data[field]
        key += val
    data['key'] = key
    return key

# will be filled with loss data => the raw IDs that were not found in the log stream
aggregated_data = {}

def ingest_data(file_name):
    file = open(file_name, 'r')
    lines = file.readlines()
    # string that only occurs in all summary lines
    TEST_SUMMARY_MARKER = 'total_input_record'
    current_data_set = []
    key = None
    for line in lines:
        if TEST_SUMMARY_MARKER in line:
            # get summary
            index = line.find('last_lost=')
            if index > 0:
                index = line.find(':', index)
                end = index - 1
                summary = line[:end]
                test_run = summary.split(',')
                
                data = process_test_run(test_run)
                if data is None:
                    continue
                key = aggregation_key(data)
                if key == '':
                    key = 'default'
                if key in aggregated_data:
                    current_data_set = aggregated_data[key]
                else:
                    current_data_set = []
                    aggregated_data[key] = current_data_set
        else:
            # get data from lines like: "1: 10001, 10002, 10003"
            begin = line.find(':')
            if begin < 0:
                continue
            raw_data = line[begin:]
            numbers = raw_data.split(',')
            for val in numbers:
                try:
                    number = int(val)
                    current_data_set.append(number)
                except ValueError:
                    continue

# meant to be run in an interactive terminal to analyze data
# customize aggregation_key with custom logic to collect data

# ingest_data('file')
# aggregated_data.keys()
# plt.hist(x)
# plt.show() 

# pyplot.hist(x, alpha=0.5, label='x')
# pyplot.hist(y, alpha=0.5, label='y')
# pyplot.legend(loc='upper right')
# pyplot.show()

#  base = '/Users/wppttt/logging-projects/aws-for-fluent-bit/troubleshooting/tools/log-loss-test-framework/results'
# file = '/fixed-re-run_below_3000.csv'
# /cross-region/fixed-re-run_3000_less.csv
# /cross-region/fixed-re-run_4000_7000.csv



def aggregation_key(data):
    key = ""
    for field in aggregate_on:
        val = data[field]
        key += val
    if data['buffer'] > 1:
        key += 'non-default-buffer'
    data['key'] = key
    return key



