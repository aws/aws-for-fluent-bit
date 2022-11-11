# Guide to Debugging Fluent Bit issues

## Table of Contents

- [Understanding Error Messages](#understanding-error-messages)
    - [How do I tell if Fluent Bit is losing logs?](#how-do-i-tell-if-fluent-bit-is-losing-logs)
    - [Tail Permission Errors](#tail-permission-errors)
    - [Overlimit warnings](#overlimit-warnings)
    - [invalid JSON message, skipping](#invalid-json-message)
- [Basic Techniques](#basic-techniques)
    - [Enable Debug Logging](#enable-debug-logging)
    - [Enabling Monitoring for Fluent Bit](#enabling-monitoring-for-fluent-bit)
    - [DNS Resolution Issues](#dns-resolution-issues)
    - [Credential Chain Resolution Issues](#credential-chain-resolution-issues)
    - [EC2 IMDSv2 Issues](#ec2-imdsv2-issues)
    - [Searching old issues](#searching-old-issues)
    - [Downgrading or upgrading your version](#downgrading-or-upgrading-your-version)
    - [Network Connection Issues](#network-connection-issues)
    - [What will the logs collected by Fluent Bit look like?](#what-will-the-logs-collected-by-fluent-bit-look-like)
- [Memory Leaks or high memory usage](#memory-leaks-or-high-memory-usage)
    - [High Memory usage does not always mean there is a leak/bug](#high-memory-usage-does-not-always-mean-there-is-a-leakbug)
    - [FireLens OOMKill Prevention Guide](#firelens-oomkill-prevention-guide)
    - [Testing for real memory leaks using Valgrind](#testing-for-real-memory-leaks-using-valgrind)
- [Segfaults and crashes (SIGSEGV)](#segfaults-and-crashes-sigsegv)
    - [Tutorial: Obtaining a core dump from Fluent Bit](#tutorial-obtaining-a-core-dump-from-fluent-bit)
- [Log Loss](#log-loss)
- [Scaling](#scaling)
- [Throttling, Log Duplication & Ordering](#throttling-log-duplication--ordering)
    - [Recommendations for throttling](#recommendations-for-throttling)
- [Plugin Specific Issues](#plugin-specific-issues)
    - [rewrite_tag filter and cycles in the log pipeline](#rewrite_tag-filter-and-cycles-in-the-log-pipeline)
    - [Use Rubular site to test regex](#use-rubular-site-to-test-regex)
    - [Chunk_Size and Buffer_Size for large logs in TCP Input](#chunk_size-and-buffer_size-for-large-logs-in-tcp-input)
    - [kinesis_streams or kinesis_firehose partially succeeded batches or duplicate records](#kinesisstreams-or-kinesisfirehose-partially-succeeded-batches-or-duplicate-records)
    - [Always use multiline in the tail input](#always-use-multiline-in-the-tail-input)
    - [Tail Input duplicates logs during rotation](#tail-input-duplicates-logs-because-of-rotation)
- [Fluent Bit Windows containers](#fluent-bit-windows-containers)
    - [Networking issue with Windows containers when using async DNS resolution by plugins](#networking-issue-with-windows-containers-when-using-async-dns-resolution-by-plugins)


### Understanding Error Messages

#### How do I tell if Fluent Bit is losing logs?

Fluent Bit is a very a low level tool, both in terms of the power over its configuration that it gives you, and in the verbosity of its log messages. Thus, it is normal to have errors in your Fluent Bit logs; its important to understand what these errors mean. 

```
[error] [http_client] broken connection to logs.us-west-2.amazonaws.com:443 ?
[error] [output:cloudwatch_logs:cloudwatch_logs.0] Failed to send log events
```

Here we see error messages associated with a single request to send logs. These errors both come from a single http request failure. It is normal for this to happen occasionally; where other tools might silently retry, Fluent Bit tells that a connection was dropped. In this case, the http client logged a connection error, and then this caused the CloudWatch plugin to log an error because the http request failed. **Seeing error messages like these does not mean that you are losing logs; Fluent Bit will retry.**

Retries can be configured: https://docs.fluentbit.io/manual/administration/scheduling-and-retries 

This is an error message indicating a chunk of logs failed and will be retried:

```
 [ warn] [engine] failed to flush chunk '1-1647467985.551788815.flb', retry in 9 seconds: task_id=0, input=forward.1 > output=cloudwatch_logs.0 (out_id=0)
```

Even if you see this message, you still have not lost logs yet. Since it will retry. You have lost logs if you see something like the following message:

```
[2022/02/16 20:11:36] [ warn] [engine] chunk '1-1645042288.260516436.flb' cannot be retried: task_id=0, input=tcp.3 > output=cloudwatch_logs.1
```

When you see this message, you have lost logs. The other case that indicates log loss is when an input is paused, which is covered in the [overlimit error section](#overlimit-warnings).

#### Tail Permission Errors
A common error message for ECS FireLens users who are reading log files is the following:

```
[2022/03/16 19:05:06] [error] [input:tail:tail.5] read error, check permissions: /var/output/logs/service_log*
```

This error will happen in many cases on startup when you use the tail input. If you are running Fluent Bit under FireLens, then remember that it alters the container ordering so that the Fluent Bit container starts first. This means that if it is supposed to scan a file path for logs on a volume mounted from another container- at startup the path might not exist. 

This error is recoverable and Fluent Bit will keep retrying to scan the path. 

There are two cases which might apply to you if you experience this error:

1. You need to fix your task definition: If you do not add a volume mount between the app container and FireLens container for your logs files, Fluent Bit can't find them and you'll get this error repeatedly.

2. This is normal, ignore the error: If you did set up the volume mount correctly, you will still always get this on startup. This is because ECS will start the FireLens container first, and so that path won't exist until the app container starts up, which is after FireLens. Thus it will always complain about not finding the path on startup. This can either be safely ignored or fixed by creating the full directory path for the log files in your Dockerfile so that it exists before any log files are written. The error will only happen on startup and once the log files exist, Fluent Bit will pick them up and begin reading them.

#### Overlimit warnings

Fluent Bit has [storage and memory buffer configuration settings](https://docs.fluentbit.io/manual/administration/buffering-and-storage).

When the storage is full the inputs will be paused and you will get warnings like the following:

```
[input] tail.1 paused (mem buf overlimit)
[input] tail.1 paused (storage buf overlimit
[input] tail.1 resume (mem buf overlimit)
[input] tail.1 resume (storage buf overlimit
```

Search for "overlimit" in the Fluent Bit logs to find the paused and resume messages about storage limits. These can be found in the code in [`flb_input_chunk.c`](https://github.com/fluent/fluent-bit/blob/master/src/flb_input_chunk.c#L1267). 

#### invalid JSON message

Users who followed [this tutorial](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/ecs-log-collection) or similar to send logs to the TCP input often see message like:

```
invalid JSON message, skipping
```

Or:

```
[debug] [input:tcp:tcp.0] JSON incomplete, waiting for more data...
```

These are caused by setting `Format json` in the TCP input. If you see these errors, then your logs are not actually being sent as JSON. Change the format to `none`. 

For example:

```
[INPUT]
    Name          tcp
    Listen        0.0.0.0
    Port          5170
# please read docs on Chunk_Size and Buffer_Size: https://docs.fluentbit.io/manual/pipeline/inputs/tcp
    Chunk_Size    32
# this number of kilobytes is the max size of single log message that can be accepted
    Buffer_Size   64
# If you set this to json you might get error: "invalid JSON message, skipping" if your logs are not actually JSON
    Format        none
    Tag           tcp-logs
# input will stop using memory and only use filesystem buffer after 50 MB
    Mem_Buf_Limit 50MB
    storage.type  filesystem 
```

### Basic Techniques

#### Enable Debug Logging

Many Fluent Bit problems can be easily understood once you have full log output. Also, if you want help from the aws-for-fluent-bit team, we generally request/require debug log output.

The log level for Fluent Bit can be set in the [Service section](https://docs.fluentbit.io/manual/administration/configuring-fluent-bit), or by setting the env var `FLB_LOG_LEVEL=debug`.

#### Enabling Monitoring for Fluent Bit

Kubernetes users should use the Fluent Bit [prometheus endpoint](https://docs.fluentbit.io/manual/administration/monitoring) and their preferred prometheus compatible agent to scrape the endpoint. 

FireLens users should check out the FireLens example for sending Fluent Bit internal metrics to CloudWatch: [amazon-ecs-firelens-examples/send-fb-metrics-to-cw](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/send-fb-internal-metrics-to-cw).

The FireLens example technique shown in the link above can also be used outside of FireLens if desired. 

#### DNS Resolution Issues

Fluent Bit has network settings that can be used with all official upstream output plugins: [Fluent Bit networking](https://docs.fluentbit.io/manual/administration/networking).

If you experience network issues, try setting the `net.dns.mode` setting to both `TCP` and `UDP`. That is, try both, and see which one resolves your issues. We have found that in different cases, one setting will work better than the other. 

Here is an example of what this looks like with `TCP`:

```
[OUTPUT]
    Name cloudwatch_logs
    Match   *
    region us-east-1
    log_group_name fluent-bit-cloudwatch
    log_stream_prefix from-fluent-bit-
    auto_create_group On
    workers 1
    net.dns.mode TCP
```

And here is an example with `UDP`:

```
[OUTPUT]
    Name cloudwatch_logs
    Match   *
    region us-east-1
    log_group_name fluent-bit-cloudwatch
    log_stream_prefix from-fluent-bit-
    auto_create_group On
    workers 1
    net.dns.mode UDP
```

This setting works with the `cloudwatch_logs`, `s3`, `kinesis_firehose`, `kinesis_streams`, and `opensearch` AWS output plugins. 

#### Credential Chain Resolution Issues

The same as other AWS tools, Fluent Bit has a standard chain of resolution for credentials. It checks a series of sources for credentails and uses the first one that returns valid credentials. If you enable debug logging (further up in this guide), then it will print verbose information on the sources of credentials that it checked and why the failed. 

See our [documentation on the credential sources Fluent Bit supports and the order of resolution](https://github.com/fluent/fluent-bit-docs/blob/43c4fe134611da471e706b0edb2f9acd7cdfdbc3/administration/aws-credentials.md).

#### EC2 IMDSv2 Issues

If you use EC2 instance role as your source for credentials you might run into issues with the new IMDSv2 system. Check out the [EC2 docs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html). 

If you run Fluent Bit in a container, you most likely will need to set the hop limit to two if you have tokens required (IMDSv2 style):

```
aws ec2 modify-instance-metadata-options \
     --instance-id <my-instance-id> \
     --http-put-response-hop-limit 2
```

The AWS cli can also be used to require IMDSv2 for security purposes:

```
aws ec2 modify-instance-metadata-options \
     --instance-id <my-instance-id> \
     --http-tokens required \
     --http-endpoint enabled
```

The other way to override the IMDS issue on EKS platform, without making the hop-limit to 2 will be setting up the hostNetwork to true, with the dnsPolicy as 'ClusterFirstWithHostNet':

```
    spec:
      dnsPolicy: ClusterFirstWithHostNet
      hostNetwork: true
```

#### Searching old issues

When you first see an issue that you don't understand, the best option is to check *open and closed* issues in both repos:
- [aws-for-fluent-bit open and closed issues](https://github.com/aws/aws-for-fluent-bit/issues?q=is%3Aissue)
- [fluent/fluent-bit open and closed issues](https://github.com/fluent/fluent-bit/issues?q=is%3Aissue)

Lots of common questions and issues have already been answered by the maintainers.

#### Downgrading or upgrading your version

If you're running on an old version, it may have been fixed in the latest release: https://github.com/aws/aws-for-fluent-bit/releases

Or, you may be facing an unresolved or not-yet-discovered issue in a newer version. Downgrading to our latest stable version may work: https://github.com/aws/aws-for-fluent-bit#using-the-stable-tag

In the AWS for Fluent Bit repo, we always attempt to tag bug reports with which versions are affected, for example see [this query](https://github.com/aws/aws-for-fluent-bit/issues?q=is%3Aissue+is%3Aopen+label%3Aaws-2.21.0).  

#### Network Connection Issues

One of the simplest causes of network connection issues is throttling, some AWS APIs will block new connections from the same IP for throttling (rather than wasting effort returning a throttling error in the response). We have seen this with the CloudWatch Logs API. So, the first thing to check when you experience network connection issues is your log ingestion/throughput rate and the limits for your destination. 

In addition, Fluent Bit's networking library and http client is very low level and simple. It can be normal for there to be occasional dropped connections or client issues. Other clients may silently auto-retry these transient issues; Fluent Bit by default will always log an error and issue a full retry with backoff for any networking error. 

This is only relavant for the core outputs, which for AWS are:
- `cloudwatch_logs`
- `kinesis_firehose`
- `kinesis_streams`
- `s3`

Remember that we also have older Golang output plugins for AWS (no longer recommended since they have poorer performance). These do not use the core fluent bit http client and networking library:
- `cloudwatch`
- `firehose`
- `kinesis`

Consequently, the AWS team contributed an `auto_retry_requests` config option for each of the core AWS outputs. This will issue an immediate retry for any connection issues. 

#### What will the logs collected by Fluent Bit look like?

This depends on what input the logs were collected with. However, in general, the raw log line for a container is encapsulated in a `log` key and a JSON is created like:

```
{
    "log": "actual line from container here",
}
```

Fluent Bit internally stores JSON encoded as msgpack. Fluent Bit can only process/ingest logs as JSON/msgpack. With FireLens, your stdout & stderr logs would look like this with if you have not disabled `enable-ecs-log-metadata`:

```
{
    "source": "stdout",
    "log": "116.82.105.169 - Homenick7462 197 [2018-11-27T21:53:38Z] \"HEAD /enable/relationships/cross-platform/partnerships\" 501 13886",
    "container_id": "e54cccfac2b87417f71877907f67879068420042828067ae0867e60a63529d35",
    "container_name": "/ecs-demo-6-container2-a4eafbb3d4c7f1e16e00"
    "ecs_cluster": "mycluster",
    "ecs_task_arn": "arn:aws:ecs:us-east-2:01234567891011:task/mycluster/3de392df-6bfa-470b-97ed-aa6f482cd7a6",
    "ecs_task_definition": "demo:7"
    "ec2_instance_id": "i-06bc83dbc2ac2fdf8"
}
```

The first 4 fields are added by the [Fluentd Docker Log Driver](https://docs.docker.com/config/containers/logging/fluentd/). The 4 ECS metadata fields are added by FireLens and are explained here:
* [FireLens example generated config](https://github.com/aws-samples/amazon-ecs-firelens-under-the-hood/blob/mainline/generated-configs/fluent-bit/generated_by_firelens.conf)
* [FireLens Under the Hood](https://aws.amazon.com/blogs/containers/under-the-hood-firelens-for-amazon-ecs-tasks/)

If you are using CloudWatch as your destination, there are additional considerations if you use the `log_key` option to just send the raw log line: [What if I just want the raw log line to appear in CW?](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/cloudwatchlogs#what-if-i-just-want-the-raw-log-line-from-the-container-to-appear-in-cloudwatch).

### Memory Leaks or high memory usage

#### High Memory usage does not always mean there is a leak/bug

Fluent Bit is efficient and performant, but it isn't magic. Here are common/normal causes of high memory usage:
- Sending logs at high throughput
- The Fluent Bit configuration and components used. Each component and extra enabled feature may incur some additional memory. Some components are more efficient than others. To give a few examples- Lua filters are powerful but can add significant overhead. Multiple outputs means that each output maintains its own request/response/processing buffers. And the rewrite_tag filter is actually implemented as a special type of input plugin that gets its own input `mem_buf_limit`. 
- Retries. This is the most common cause of complaints of high memory usage. When an output issues a retry, the Fluent Bit pipeline must buffer that data until it is successfully sent or the configured retries expire. Since retries have exponential backoff, a series of retries can very quickly lead to a large number of logs being buffered for a long time. 

Please see the Fluent Bit buffering documentation: https://docs.fluentbit.io/manual/administration/buffering-and-storage

#### FireLens OOMKill Prevention Guide

Check out the FireLens example for preventing/reducing out of memory exceptions: [amazon-ecs-firelens-examples/oomkill-prevention](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/oomkill-prevention)

#### Testing for real memory leaks using Valgrind

If you do think the cause of your high memory usage is a bug in the code, you can optionally help us out by attempting to profile Fluent Bit for the source of the leak. To do this, use the [Valgrind](https://valgrind.org/) tool.

There are some caveats when using Valgrind. Its a debugging tool, and so it significantly reduces the performance of Fluent Bit. It will consume more memory and CPU and generally be slower when debugging. Therefore, Valgrind images may not be safe to deploy to prod. 

##### Option 1: Build from prod release (Easier but less robust)

Use the Dockerfile below to create a new container image that will invoke your Fluent Bit version using Valgrind. Replace the "builder" image with whatever AWS for Fluent Bit release you are using, in this case, we are testing the latest image. The Dockerfile here will copy the original binary into a new image with Valgrind. Valgrind is a little bit like a mini-VM that will run the Fluent Bit binary and inspect the code at runtime. When you terminate the container, Valgrind will output diagnostic information on shutdown, with summary of memory leaks it detected. This output will allow us to determine which part of the code caused the leak. Valgrind can also be used to find the source of segmentation faults

```
FROM public.ecr.aws/aws-observability/aws-for-fluent-bit:latest as builder

FROM public.ecr.aws/amazonlinux/amazonlinux:latest
RUN yum upgrade -y \
    && yum install -y openssl11-devel \
          cyrus-sasl-devel \
          pkgconfig \
          systemd-devel \
          zlib-devel \
          libyaml \
          valgrind \
          nc && rm -fr /var/cache/yum

COPY --from=builder /fluent-bit /fluent-bit
CMD valgrind --leak-check=full --error-limit=no /fluent-bit/bin/fluent-bit -c /fluent-bit/etc/fluent-bit.conf
```

##### Option 2: Debug Build (More robust)

The best option, which is most likely to catch any leak or segfault is to create a fresh build of the image using the [`Dockerfile.debug`](https://github.com/aws/aws-for-fluent-bit/blob/mainline/Dockerfile.debug) in AWS for Fluent Bit. This will create a fresh build with debug mode and valgrind support enabled, which gives the highest chance that Valgrind will be albe to produce useful diagnostic information about the issue. 

1. Check out the git tag for the version that saw the problem
2. Make sure the `FLB_VERSION` at the top of the `Dockerfile.debug` is set to the same version as the main Dockerfile for that tag. 
3. Build this dockerfile with the `make debug` target. 

### Segfaults and crashes (SIGSEGV)

One technique is to use the Option 2 shown above for memory leak checking with Valgrind. It can also find the source of segmentation faults; when Fluent Bit crashes Valgrind will output a stack trace that shows which line of code caused the crash. That information will allow us to fix the issue. This requires the use of [Option 2: Debug Build](#option-2-debug-build-more-robust) above where you re-build AWS for Fluent Bit in debug mode. 

Alternatively, the best and most effective way to debug a crash is to get a core dump. 

#### Tutorial: Obtaining a Core Dump from Fluent Bit

Follow our standalone core dump debugging tutorial which supports multiple AWS platforms: [Tutorial: Debugging Fluent Bit with GDB](tutorials/remote-core-dump/README.md).

### Log Loss

The most common cause of log loss is failed retries. Check your Fluent Bit logs for those error messages. Figure out why retries are failing, and then solve that issue.

If you find that you are losing logs and failed retries do not seem to be the issue, then the technique commonly used by the aws-for-fluent-bit team is to use a data generate that creates logs with unique IDs. At the log destination, you can then count the unique IDs and know exactly how many logs were lost. These unique IDs should ideally be some sort of number that counts up. You can then determine patterns for the lost logs, for example- are the lost logs grouped in chunks together, or do they all come from a single log file, etc. 

We have uploaded some tools that we have used for past log loss investigations in the [troubleshooting/tools](tools) directory. 

Finally, we should note that the AWS plugins go through log loss testing as part of our release pipeline, and log loss will block releases. We are working on improving our test framework; you can find it in the [integ/](integ/) directory.

We also now have log loss and throughput benchmarks as part of our release notes.

### Scaling

While the Fluent Bit maintainers are constantly working to improve its max performance, there are limitations. Carefully architecting your Fluent Bit deployment can ensure it can scale to meet your required throughput. 

If you are handling very high throughput of logs, consider the following:
1. Switch to a sidecar deployment model if you are using a Daemon/Daemonset. In the sidecar model, there is a dedicated Fluent Bit container for each application container/pod/task. This means that as you scale out to more app containers, you automatically scale out to more Fluent Bit containers as well. 
2. Enable Workers. Workers is a new feature for multi-threading in core outputs. Even enabling a single worker can help, as it is a dedicated thread for that output instance. All of the AWS core outputs support workers:
    - https://docs.fluentbit.io/manual/pipeline/outputs/cloudwatch#worker-support
    - https://docs.fluentbit.io/manual/pipeline/outputs/kinesis#worker-support
    - https://docs.fluentbit.io/manual/pipeline/outputs/firehose#worker-support
    - https://docs.fluentbit.io/manual/pipeline/outputs/s3#worker-support 
3. Use a log streaming model instead of tailing log files. The AWS team has repeatedly found that complaints of scaling problems usually are cases where the tail input is used. Tailing log files and watching for rotations is inherently costly and slower than a direct streaming model. [Amazon ECS FireLens](https://aws.amazon.com/blogs/containers/under-the-hood-firelens-for-amazon-ecs-tasks/) is one good example of direct streaming model (that also uses sidecar for more scalability)- logs are sent from the container stdout/stderr stream via the container runtime over a unix socket to a Fluent Bit [forward](https://docs.fluentbit.io/manual/pipeline/inputs/forward) input. Another option is to use the [TCP input which can work with some loggers, including log4j](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/ecs-log-collection#tutorial-3-using-log4j-with-tcp). 

### Throttling, Log Duplication & Ordering

To understand how to deal with these issues, it's important to understand the Fluent Bit log pipeline. Logs are ingested from inputs and buffered in chunks, and then chunks are delivered to the output plugin. When an output plugin recieves a chunk it only has 3 options for its return value to the core pipeline:
* FLB_OK: the entire chunk was successfully sent/handled
* FLB_RETRY: retry the entire chunk up to the max user configured retries
* FLB_ERROR: something went very wrong, don't retry

Because AWS APIs have a max payload size, and the size of the chunks sent to the output is not directly user configurable, this means that a single chunk may be sent in multiple API requests. If one of those requests fails, the output plugin can only tell the core pipeline to *retry the entire chunk*. This means that send failures, including throttling, can lead to duplicated data. Because when the retry happens, the output plugin has no way to track that some of the chunk was already uploaded. 

Additionally, while a chunk that got an FLB_RETRY will be retried with exponential backoff, the pipeline will continue to send newer chunks to the output in the meantime. This means that data ordering can not be strictly guaranteed. The exception to this is the S3 plugin with the `preserve_data_ordering` feature, which works because the S3 output maintains its own separate buffer of data in the local file system. 

Finally, this behavior means that if a chunk fails because of throttling, that specific chunk will backoff, but the engine will not backoff from sending new logs to the output. Consequently, its very important to ensure that your destination can handle your log ingestion rate and that you will not be throttled.

The AWS team understands that the current behavior of the core log pipeline is not ideal for all use cases, and we have taken long term action items to improve it:
* [Allow output plugins to configure a max chunk size: fluent-bit#1938](https://github.com/fluent/fluent-bit/issues/1938)
* [FLB_THROTTLE return for outputs: fluent-bit#4293](https://github.com/fluent/fluent-bit/issues/4293)

NOTE: If you are using the tail input and your `Path` pattern matches rotated log files, [this misconfiguration can lead to duplicated logs](#tail-input-duplicates-logs-because-of-rotation). 

#### Recommendations for throttling

* If you are using Kinesis Streams of Kinesis Firehose, scale your stream to handle your max required throughput
* For CloudWatch Log Streams, there is currently a hard ingestion limit per stream. Thus, the solution is to scale out to more streams. Since the best practice is one log stream per app container, this means scaling out to more app containers so that each performs less work and thus produces fewer logs, and also so that there are more log streams.  

### Plugin Specific Issues

#### rewrite_tag filter and cycles in the log pipeline

The [rewrite_tag](https://docs.fluentbit.io/manual/pipeline/filters/rewrite-tag) filter is a very powerful part of the log pipeline. It allows you to define a filter that is actually an input that will re-emit log records with a new tag. 

However, with great power comes great responsibility... a common mistake that causes confusing issues is for the rewrite_tag filter to match the logs that it re-emits. This will make the log pipeline circular, and Fluent Bit will just get stuck. Your rewrite_tag filter should never match "*" and you must think very carefully about how you are configuring the Fluent Bit pipeline. 

#### Use Rubular site to test regex

To experiment with regex for parsers, the Fluentd and Fluent Bit community recommends using this site: https://rubular.com/

#### Chunk_Size and Buffer_Size for large logs in TCP Input

Many users will have seen our [tutorial on sending logs over the Fluent Bit TCP input](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/ecs-log-collection). 

It should be noted that if your logs are very large, they can be dropped by the TCP input unless the appropriate settings are set. 

For the TCP input, the Buffer_Size is the max size of single event sent to the TCP input that can be accepted. Chunk_size is for rounds of memory allocation, this must be set based on the customer’s average/median log size. This setting is for performance and exposes the low level memory allocation strategy. https://docs.fluentbit.io/manual/pipeline/inputs/tcp

The following configuration may be more efficient in terms of memory consumption, if logs are normally smaller than Chunk_Size and TCP connections are reused to send logs many times. It uses smaller amounts of memory by default for the TCP buffer, and reallocates the buffer in increments of Chunk_Size if the current buffer size is not sufficient. It will be slightly less computationally efficient if logs are consistently larger than Chunk_Size, as reallocation will be needed with each new TCP connection. If the same TCP connection is reused, the expanded buffer will also be reused. (TCP connections are probably kept open for a long time so this is most likely not an issue).

```
    Buffer_Size 64 # KB, this is the max log event size that can be accepted
    Chunk_Size 32 # allocation size each time buffer needs to be increased
```

#### kinesis_streams or kinesis_firehose partially succeeded batches or duplicate records

As noted in the [duplication section of this guide](#throttling-log-duplication--ordering), unfortunately Fluent Bit can sometimes upload the same record multiple times due to retries that partially succeeded. While this is a problem with Fluent Bit outputs in general, it is especially a problem for Firehose and Kinesis since their service APIs allow a request to upload data to partially succeed:
- [PutRecords](https://docs.aws.amazon.com/kinesis/latest/APIReference/API_PutRecords.html)
- [PutRecordBatch](https://docs.aws.amazon.com/firehose/latest/APIReference/API_PutRecordBatch.html)

Each API accepts 500 records in a request, and some of these records may be uploaded to the stream and some may fail. As noted in the [duplication section of this guide](#throttling-log-duplication--ordering), when a chunk partially succeeds, Fluent Bit must retry the entire chunk. That retry could again fail with partial success, leading to another retry (up to your configured `Retry_Limit`). Thus, log duplication can be common with these outputs. 

When a batch partially fails, you will get a message like:

```
[error] [output:kinesis_streams:kinesis_streams.0] 132 out of 500 records failed to be delivered, will retry this batch, {stream name}
```

Or:

```
[error] [output:kinesis_firehose:kinesis_firehose.0] 6 out of 500 records failed to be delivered, will retry this batch, {stream name}
```

To see the reason why each individual record failed, please [enable debug logging](#enable-debug-logging). These outputs will print the exact error message for each record as a debug log:
- [kinesis_firehose API response processing code](https://github.com/fluent/fluent-bit/blob/1.8/plugins/out_kinesis_firehose/firehose_api.c#L702)
- [kinesis_streams API response processing code](https://github.com/fluent/fluent-bit/blob/1.8/plugins/out_kinesis_streams/kinesis_api.c#L767)

The most common cause of failures for kinesis and firehose is a `Throughput Exceeded Exception`. This means you need to increase the limits/number of streams for your Firehose or Kinesis stream. 
- [Kinesis Service Throttling](https://aws.amazon.com/premiumsupport/knowledge-center/kinesis-data-stream-throttling/)
- [Firehose Service FAQ](https://aws.amazon.com/kinesis/data-firehose/faqs/)

#### Always use multiline in the tail input

Fluent Bit supports a [multiline filter](https://docs.fluentbit.io/manual/pipeline/filters/multiline-stacktrace) which can concat logs. 

However, Fluent Bit also supports [multiline parsers in the tail input](https://docs.fluentbit.io/manual/pipeline/inputs/tail#multiline-core-v1.8) directly. If your logs are ingested via tail, you should always use the multiple settings in the tail input. That will be much more performant. Fluent Bit can concat the log lines as it reads them. This is more efficient than ingesting them as individual records and then using the filter to re-concat them. 

#### Tail input duplicates logs because of rotation

As noted in the [Fluent Bit upstream docs](https://docs.fluentbit.io/manual/pipeline/inputs/tail#file-rotation), your tail `Path` patterns can not match rotated log files. If it does, the contents of the log file may be read a second time once its name is changed.

For example, if you have this tail input:

```
[INPUT]
    Name                tail
    Tag                 RequestLogs
    Path                /logs/request.log*
    Refresh_Interval    1
```

Assume that after the `request.log` file reaches its max size it is rotated to `request.log1` and then new logs are written to a new file called `request.log`. This is the behavior of the [log4j DefaultRolloverStrategy](https://logging.apache.org/log4j/2.x/manual/appenders.html#DefaultRolloverStrategy).

If this is how your app writes log files, then you will get duplicate log events with this configuration. Because the `Path` pattern matches the same log file both before and after it is rotated. Fluent Bit may read the `request.log1` as a new log file and thus its contents can be sent twice. In this case, the solution is to change to:

```
Path                /logs/request.log
```

In other cases, the original config would be correct. For example, assume your app produces first a log file `request.log` and then next creates and writes new logs to a new file named `request.log1` and then next `request.log2`. And then when the max number of files are reached, the original `request.log` is deleted and then a new `request.log` is written. If that is the scenario, then the original Path pattern with a wildcard at the end is correct since it is necessary to match all log files where new logs are written. This method of log rotation is the behavior of the [log4j DirectWriteRolloverStrategy](https://logging.apache.org/log4j/2.x/manual/appenders.html#DirectWriteRolloverStrategy) where there is no file renaming. 

### Fluent Bit Windows containers

#### Networking issue with Windows containers when using `async` DNS resolution by plugins
There are Fluent Bit core plugins which are using the default [async mode for performance improvement](https://github.com/fluent/fluent-bit/blob/master/DEVELOPER_GUIDE.md#concurrency). Ideally when there are multiple nameservers present in a network namespace, the DNS resolver should retry with other nameservers if it receives failure response from the first one. However, Fluent Bit version 1.9 had a bug wherein the DNS resolution failed after first failure. The Fluent Bit Github issue link is [here](https://github.com/fluent/fluent-bit/issues/5862).

This is an issue for Windows containers running in `default` network where the first DNS server is the one used only for DNS resolution within container network i.e. resolving other containers connected on the network. Therefore, all other DNS queries fail with the first nameserver.

To work around this issue, we suggest using the following option so that system DNS resolver is used by Fluent Bit which works as expected.
```
net.dns.mode LEGACY
```
