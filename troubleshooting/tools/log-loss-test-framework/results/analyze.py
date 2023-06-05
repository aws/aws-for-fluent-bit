import csv
import sys
import statistics
from markdownTable import markdownTable

'''
@message
4000KB_1KB_AWSLOGS_10m_BUFFER_FARGATE_AUTO ✅ - 4000, percent lost, 0, number_lost, 0, total_input_record, 1000000, duplicates, 11, group=awslogs-benchmarking-output stream=awslogs-benchmarking-output TOTAL_SIZE_IN_MB=1000, SIZE_IN_MB=1, THROUGHPUT_IN_KB=4000, dae1939c065e4a2a820f24131015d8f2, arn:aws:ecs:us-west-2:144718711470:cluster/awslogs-benchmarking-ec2-patched, awslogs-benchmarking-fargate-10m-buffer-automated-250K-log:3, FARGATE, us-west-2
3000KB_1KB_AWSLOGS_10m_BUFFER_FARGATE_AUTO ✅ - 3000, percent lost, 0, number_lost, 0, total_input_record, 1000000, duplicates, 11, group=awslogs-benchmarking-output stream=awslogs-benchmarking-output TOTAL_SIZE_IN_MB=1000, SIZE_IN_MB=1, THROUGHPUT_IN_KB=3000, e3c58cc72ed54af19a123de020422bc2, arn:aws:ecs:us-west-2:144718711470:cluster/awslogs-benchmarking-ec2-patched, awslogs-benchmarking-fargate-10m-buffer-automated-250K-log:2, FARGATE, us-west-2
3000KB_1KB_AWSLOGS_10m_BUFFER_FARGATE_AUTO ✅ - 3000, percent lost, 0, number_lost, 0, total_input_record, 1000000, duplicates, 11, group=awslogs-benchmarking-output stream=awslogs-benchmarking-output TOTAL_SIZE_IN_MB=1000, SIZE_IN_MB=1, THROUGHPUT_IN_KB=3000, f0c36c3adf9341fcba3334dbac015a27, arn:aws:ecs:us-west-2:144718711470:cluster/awslogs-benchmarking-ec2-patched, awslogs-benchmarking-fargate-10m-buffer-automated-250K-log:2, FARGATE, us-west-2
4000KB_1KB_AWSLOGS_10m_BUFFER_FARGATE_AUTO ✅ - 4000, percent lost, 0, number_lost, 0, total_input_record, 1000000, duplicates, 11, group=awslogs-benchmarking-output stream=awslogs-benchmarking-output TOTAL_SIZE_IN_MB=1000, SIZE_IN_MB=1, THROUGHPUT_IN_KB=4000, 71710122e5eb43efa97e408ecacf0c9e, arn:aws:ecs:us-west-2:144718711470:cluster/awslogs-benchmarking-ec2-patched, awslogs-benchmarking-fargate-10m-buffer-automated-250K-log:3, FARGATE, us-west-2
3000KB_1KB_AWSLOGS_10m_BUFFER_FARGATE_AUTO ✅ - 3000, percent lost, 0, number_lost, 0, total_input_record, 1000000, duplicates, 11, group=awslogs-benchmarking-output stream=awslogs-benchmarking-output TOTAL_SIZE_IN_MB=1000, SIZE_IN_MB=1, THROUGHPUT_IN_KB=3000, a18fc146860e4acbb2ea044b29cde6e3, arn:aws:ecs:us-west-2:144718711470:cluster/awslogs-benchmarking-ec2-patched, awslogs-benchmarking-fargate-10m-buffer-automated-250K-log:2, FARGATE, us-west-2
'''

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

RESULT_SEPARATOR = '______________'

task_ids_found = {}

results = []
result_sets = {}

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
    global task_ids_found
    test_name = test_run[0].strip()
    # percent_lost = test_run[2].strip()
    number_lost = test_run[4].strip()
    total_input_record = test_run[6].strip()
    success = False
    if number_lost == "0":
        success = True
    tmp = test_run[10].strip()
    split = tmp.split("=")
    log_size = split[1]
    tmp = test_run[11].strip()
    split = tmp.split("=")
    throughput = int(split[1])
    task_id = test_run[12]
    cluster = test_run[13].strip()
    if '/' in cluster: # some output has cluster ARN, some just name, not sure why
        split = cluster.split("/")
        cluster = split[1]
    launch_type = test_run[15].strip()
    buffer_size = 0
    for pattern in TEST_NAMES_TO_BUFFER_SIZES:
        if pattern in test_name:
            buffer_size = TEST_NAMES_TO_BUFFER_SIZES[pattern]

    if buffer_size == 0:
        print("could not find buffer size in " + test_name)
        return None

    # use task ID to guard against duplicate test results pasted into the output due to human error
    if task_ids_found.get(task_id):
        print("ERROR: duplicate test run "+ test_name)
        return None
    task_ids_found[task_id] = True

    # accurate calculation of loss percent with float
    lost = float(number_lost)
    total_records = float(total_input_record)

    percent_lost = (lost / total_records) * 100

    # This the key used to collect test results for the stats summary
    # Modify this if you want change how test results
    # are compiled
    # For example: remove launchType to summarize both EC2 and Fargate together
    key = f'{launch_type}_BUFFER={buffer_size}_RATE={throughput}KB/s_MSG={log_size}KB_CLUSTER={cluster}'

    return {
        'test_name': test_name,
        'success': success,
        'loss_%': percent_lost,
        'total_input_record': total_input_record,
        'number_lost': number_lost,
        'log_size': log_size,
        'throughput': throughput,
        'cluster': cluster,
        'launch_type': launch_type,
        'buffer': buffer_size,
        'key': key,
    }



# creates a table based on specific dimensions
# for example, pass in dimensions = { 'launch_type': 'EC2', 'log_size': '1'}
# and you get a data table for all EC2 tests with 1KB log messages
# outputs 3 tables, each for the following metric: 'successful_runs', 'max_loss', 'avg_loss'
def results_table_with_dimensions(test_runs, dimensions):
    runs_with_dimensions = []
    test_sets = {}
    result_table_success = {}
    result_table_avg = {}
    result_table_max = {}
    result_table_stdev = {}
    all_tables = {
        'success': result_table_success,
        'avg': result_table_avg,
        'max': result_table_max,
        'stdev': result_table_stdev,
    }
    buffer_sizes_found = []
    throughputs_found = []


    # collect the runs with these dimension values
    for test_run in test_runs:
        include_run = True
        for key in dimensions:
            if test_run[key] != dimensions[key]:
                include_run = False

        if include_run:
            runs_with_dimensions.append(test_run)


    # collect the runs by throughput and buffer size
    for test_run in runs_with_dimensions:
        throughput = test_run['throughput']
        buffer_size = test_run['buffer']
        key = f'BUFFER={buffer_size}_RATE={throughput}'
        if key in test_sets:
            test_sets[key].append(test_run)
        else:
            test_sets[key] = [ test_run ]
        # track buffer sizes and throughputs in this set of test results
        if buffer_size not in buffer_sizes_found:
            buffer_sizes_found.append(buffer_size)

        if throughput not in throughputs_found:
            throughputs_found.append(throughput)

    # TODO: add parsing of new info from test_run_checker
    # some runs had TOTAL_SIZE_IN_MB=500 and count for half of a run
    # compared with all others that had TOTAL_SIZE_IN_MB=1000

    # compute simple stats on the test runs for each combination of buffer size and throughput
    for test_case in test_sets:
        total_runs = len(test_sets[test_case])
        successful_runs = 0
        buffer_size = 0
        throughput = 0
        max_loss = 0
        loss_values = []
        for test_run in test_sets[test_case]:
            throughput = test_run['throughput']
            buffer_size = test_run['buffer']
            if test_run['success']:
                successful_runs += 1
            loss = test_run['loss_%']
            loss_values.append(loss)
            if loss > max_loss:
                max_loss = loss

        avg_loss = statistics.mean(loss_values)
        stdev_loss = statistics.pstdev(loss_values)

        metric_stdev = '🚨'
        if stdev_loss <= 1:
            metric_stdev = '✅'
        elif stdev_loss <= 2:
            metric_stdev = '❕'
        elif stdev_loss <= 5:
            metric_stdev = '❗️'
        elif stdev_loss <= 10:
            metric_stdev = '❌'

        table_summary_stdev = f'{metric_stdev} {stdev_loss:.2f}'

        metric_avg = '🚨'
        if avg_loss == 0:
            metric_avg = '✅'
        elif avg_loss <= 0.5:
            metric_avg = '❕'
        elif avg_loss <= 1:
            metric_avg = '❗️'
        elif avg_loss <= 5:
            metric_avg = '❌'

        if avg_loss == 0:
            table_summary_avg = f'{metric_avg}'
        else:
            table_summary_avg = f'{metric_avg} {avg_loss:.2f}%'

        metric_max = '🚨'
        if max_loss == 0:
            metric_max = '✅'
        elif max_loss <= 1:
            metric_max = '❕'
        elif max_loss <= 5:
            metric_max = '❗️'
        elif max_loss <= 10:
            metric_max = '❌'

        if max_loss == 0:
            table_summary_max = f'{metric_max}'
        else:
            table_summary_max = f'{metric_max} {max_loss:.2f}%'

        metric_success = '🚨'
        if successful_runs == total_runs:
            metric_success = '✅'
        elif (successful_runs / total_runs) > 0.9 and (total_runs - successful_runs) == 1:
            metric_success = '❕'
        elif (successful_runs / total_runs) > 0.95:
            metric_success = '❗️'
        elif (successful_runs / total_runs) > 0.9:
            metric_success = '❌'
        
        table_summary_success = f'{metric_success} {successful_runs}/{total_runs}'

        table_summaries = {
            'success': table_summary_success,
            'avg': table_summary_avg,
            'max': table_summary_max,
            'stdev': table_summary_stdev,
        }

        for table_type in all_tables:
            summary = table_summaries[table_type]
            table = all_tables[table_type]
            if throughput not in table:
                table[throughput] = {}
            table[throughput][buffer_size] = summary

    buffer_sizes_found.sort()
    throughputs_found.sort()

    # print data table summary in CSV
    print('\n\n' + RESULT_SEPARATOR + RESULT_SEPARATOR)
    print(RESULT_SEPARATOR, end="")
    for key in dimensions:
        val = dimensions[key]
        print(f'{key}={val} ', end="")
    
    if len(dimensions) == 0:
        print("ALL", end="")

    print(RESULT_SEPARATOR)
    print(RESULT_SEPARATOR + RESULT_SEPARATOR + '\n\n')

    print(f'test runs with these dimensions = {len(runs_with_dimensions)}\n\n')

    for table_type in all_tables:
        print(RESULT_SEPARATOR + "loss " + table_type + RESULT_SEPARATOR)
        table = all_tables[table_type]
        # print CSV table
        print("--", end=", ")
        for buffer_size in buffer_sizes_found:
            print(buffer_size, end=", ")
        print("")
        for throughput in throughputs_found:
            print(throughput, end=", ")
            for buffer_size in buffer_sizes_found:
                tmp = table.get(throughput)
                summary = None
                if tmp is not None:
                    summary = tmp.get(buffer_size)
                if summary is None:
                    summary = "--"

                print(summary, end=", ")
            print("")

        print('\n\n')

all_test_runs = []

with open(sys.argv[1]) as csv_file:
    csv_reader = csv.reader(csv_file, delimiter=',')
    line_count = 0
    for row in csv_reader:
        line_count += 1
        test_run = list(row)
        if 'BUG' in test_run[0]: # skip AWSLogs non-blocking bug test runs
            continue
        err = validate_test_run(test_run)
        if err != "":
            print("INVALID DATA: NOT FOUND: " + err + ",  --\n  " + ", ".join(test_run))
            continue

        data = process_test_run(test_run)
        if data == None:
            print("INVALID DATA: " + ", ".join(test_run))
            continue

        all_test_runs.append(data)
        
        key = data['key']
        if key in result_sets:
            result_sets[key].append(data)
        else:
            result_sets[key] = [ data ]
    print(f'Processed {line_count} test runs.')

    for test_case in result_sets:
        total_runs = len(result_sets[test_case])
        max_loss = 0
        min_loss = 100
        successful_runs = 0
        buffer_size = 0
        throughput = 0
        launch_type = ""
        loss_values = []
        for test_run in result_sets[test_case]:
            throughput = test_run['throughput']
            buffer_size = test_run['buffer']
            launch_type = test_run['launch_type']
            if test_run['success']:
                successful_runs += 1
            loss = test_run['loss_%']
            loss_values.append(loss)
            if loss > max_loss:
                max_loss = loss
            if loss < min_loss:
                min_loss = loss

        avg_loss = statistics.mean(loss_values)
        stdev_loss = statistics.pstdev(loss_values)

        success = '🚨'
        if successful_runs == total_runs:
            success = '✅'
        summary = f'{test_case}: {success} {successful_runs}/{total_runs} Loss % metrics: AVG: {avg_loss}, MAX: {max_loss}, MIN: {min_loss}, STDEV: {stdev_loss}'
        results.append(summary)

    # sort so that data is ordered with buffer sizes together
    results.sort()
    for result in results:
        print(result)

    # All results compiled into one table:
    results_table_with_dimensions(all_test_runs, {})

    # ALL EC2
    results_table_with_dimensions(all_test_runs, { 'launch_type': 'EC2'})

    # All Fargate
    results_table_with_dimensions(all_test_runs, { 'launch_type': 'FARGATE'})
    
    # by log size

    results_table_with_dimensions(all_test_runs, { 'log_size': '1'})

    results_table_with_dimensions(all_test_runs, { 'log_size': '250'})
