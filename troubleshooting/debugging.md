# Guide to Debugging Fluent Bit issues

## Table of Contents

- [Understanding Error Messages](#understanding-error-messages)
    - [How do I tell if Fluent Bit is losing logs?](#how-do-i-tell-if-fluent-bit-is-losing-logs)
    - [Tail Permission Errors](#tail-permission-errors)
    - [Overlimit warnings](#overlimit-warnings)
- [Basic Techniques](#basic-techniques)
    - [Enable Debug Logging](#enable-debug-logging)
    - [Enabling Monitoring for Fluent Bit](#enabling-monitoring-for-fluent-bit)
    - [DNS Resolution Issues](#dns-resolution-issues)
    - [Credential Chain Resolution Issues](#credential-chain-resolution-issues)
    - [EC2 IMDSv2 Issues](#ec2-imdsv2-issues)
    - [Searching old issues](#searching-old-issues)
    - [Downgrading or upgrading your version](#downgrading-or-upgrading-your-version)
    - [Network Connection Issues](#network-connection-issues)
- [Memory Leaks or high memory usage](#memory-leaks-or-high-memory-usage)
    - [High Memory usage does not always mean there is a leak/bug](#high-memory-usage-does-not-always-mean-there-is-a-leakbug)
    - [FireLens OOMKill Prevention Guide](#firelens-oomkill-prevention-guide)
    - [Testing for real memory leaks using Valgrind](#testing-for-real-memory-leaks-using-valgrind)
- [Segfaults and crashes (SIGSEGV)](#segfaults-and-crashes-sigsegv)
- [Log Loss](#log-loss)
- [Scaling](#scaling)
- [Throttling, Log Duplication & Ordering](#throttling-log-duplication--ordering)
    - [Recommendations for throttling](#recommendations-for-throttling)
- [Plugin Specific Issues](#plugin-specific-issues)
    - [rewrite_tag filter and cycles in the log pipeline](#rewritetag-filter-and-cycles-in-the-log-pipeline)
    - [Use Rubular site to test regex](#use-rubular-site-to-test-regex)
    - [Chunk_Size and Buffer_Size for large logs in TCP Input](#chunk_size-and-buffer_size-for-large-logs-in-tcp-input)



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
    net.dns.mode
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

Use the Dockerfile below to create a new container image that will invoke your Fluent Bit version using Valgrind. Replace the "builder" image with whatever AWS for Fluent Bit release you are using, in this case, we are testing 2.21.0. The Dockerfile here will copy the original binary into a new image with Valgrind. Valgrind is a little bit like a mini-VM that will run the Fluent Bit binary and inspect the code at runtime. When you terminate the container, Valgrind will output diagnostic information on shutdown, with summary of memory leaks it detected. This output will allow us to determine which part of the code caused the leak. Valgrind can also be used to find the source of segmentation faults

```
FROM public.ecr.aws/aws-observability/aws-for-fluent-bit:2.21.0 as builder

FROM public.ecr.aws/amazonlinux/amazonlinux:latest
RUN yum upgrade -y \
    && yum install -y openssl11-devel \
          cyrus-sasl-devel \
          pkgconfig \
          systemd-devel \
          zlib-devel \
          valgrind \
          nc && rm -fr /var/cache/yum

COPY --from=builder /fluent-bit /fluent-bit
CMD valgrind --leak-check=full /fluent-bit/bin/fluent-bit -c /fluent-bit/etc/fluent-bit.conf
```

##### Option 2: Debug Build (More robust)

The best option, which is most likely to catch any leak or segfault is to create a fresh build of the image using the [`Dockerfile.debug`](https://github.com/aws/aws-for-fluent-bit/blob/mainline/Dockerfile.debug) in AWS for Fluent Bit. This will create a fresh build with debug mode and valgrind support enabled, which gives the highest chance that Valgrind will be albe to produce useful diagnostic information about the issue. 

1. Check out the git tag for the version that saw the problem
2. Make sure the `FLB_VERSION` at the top of the `Dockerfile.debug` is set to the same version as the main Dockerfile for that tag. 
3. Build this dockerfile with the `make debug` target. 

### Segfaults and crashes (SIGSEGV)

Use the Option 2 shown above for memory leak checking with Valgrind. It can also find the source of segmentation faults; when Fluent Bit crashes Valgrind will output a stack trace that shows which line of code caused the crash. That information will allow us to fix the issue. This requires the use of **Option 2** where you re-build AWS for Fluent Bit in debug mode. 

Alternatively, if you don't want the overhead of Valgrind, change the entrypoint in the `Dockerfile.debug` to the core file option by un-commenting the lines at the end of the file. 

And then run Fluent Bit with ulimit unlimited and with the `/cores` directory mounted onto your host:
```
docker run --ulimit core=-1 -v /somehostpath:/cores ...
```

When the debug mode enabled Fluent Bit crashes, a core file should be outputted to `/somehostpath`. 

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

