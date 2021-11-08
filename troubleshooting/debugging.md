## Guide to Debugging Fluent Bit issues

### Basic Techniques

#### Enable Debug Logging

Many Fluent Bit problems can be easily understood once you have full log output. Also, if you want help from the aws-for-fluent-bit team, we generally request/require debug log output.

The log level for Fluent Bit can be set in the [Service section](https://docs.fluentbit.io/manual/administration/configuring-fluent-bit/configuration-file), or by setting the env var `FLB_LOG_LEVEL=debug`.

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

#### Tail Permission Issues in FireLens

```
[2021/11/23 16:14:15] [debug] [input:tail:tail.5] scanning path /workspace/env/<Service>/var/output/logs/service_log*
[2021/11/23 16:14:15] [error] [input:tail:tail.5] read error, check permissions: /workspace/env/<Service>/var/output/logs/service_log*
[2021/11/23 16:14:15] [ warn] [input:tail:tail.5] error scanning path: /workspace/env/<Service>/var/output/logs/service_log*
```

This error will happen in many cases on startup when you use the tail input. If you are running Fluent Bit under FireLens, then remember that it alters the container ordering so that the Fluent Bit container starts first. This means that if it is supposed to scan a file path for logs on a volume mounted from another container- at startup the path might not exist. 

This error is recoverable and Fluent Bit will keep retrying to scan the path. 

### Memory Leaks or high memory usage

#### High Memory usage does not always mean there is a leak/bug

Fluent Bit is efficient and performant, but it isn't magic. Here are common/normal causes of high memory usage:
- Sending logs at high throughput
- The Fluent Bit configuration and components used. Each component and extra enabled feature may incur some additional memory. Some components are more efficient than others. To give a few examples- Lua filters are powerful but can add significant overhead. Multiple outputs means that each output maintains its own request/response/processing buffers. And the rewrite_tag filter is actually implemented as a special type of input plugin that gets its own input `mem_buf_limit`. 
- Retries. This is the most common cause of complaints of high memory usage. When an output issues a retry, the Fluent Bit pipeline must buffer that data until it is successfully sent or the configured retries expire. Since retries have exponential backoff, a series of retries can very quickly lead to a large number of logs being buffered for a long time. 

Please see the Fluent Bit buffering documentation: https://docs.fluentbit.io/manual/administration/buffering-and-storage

#### Testing for real memory leaks

If you do think the cause of your high memory usage is a bug in the code, you can optionally help us out by attempting to profile Fluent Bit for the source of the leak. To do this, use the [Valgrind](https://valgrind.org/) tool.

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

There are some caveats when using Valgrind. Its a debugging tool, and so it significantly reduces the performance of Fluent Bit. It will consume more memory and CPU and generally be slower when debugging. Therefore, Valgrind images may not be safe to deploy to prod. 

### Segfaults and crashes (SIGSEGV)

Use the technique shown above for memory leak checking with Valgrind. It can also find the source of segmentation faults; when Fluent Bit crashes Valgrind will output a stack trace that shows which line of code caused the crash. That information will allow us to fix the issue. 

### Log Loss

The most common cause of log loss is failed retries. Check your Fluent Bit logs for those error messages. Figure out why retries are failing, and then solve that issue.

If you find that you are losing logs and failed retries do not seem to be the issue, then the technique commonly used by the aws-for-fluent-bit team is to use a data generate that creates logs with unique IDs. At the log destination, you can then count the unique IDs and know exactly how many logs were lost. These unique IDs should ideally be some sort of number that counts up. You can then determine patterns for the lost logs, for example- are the lost logs grouped in chunks together, or do they all come from a single log file, etc. 

We have uploaded some tools that we have used for past log loss investigations in the [troubleshooting/tools](tools) directory. 

Finally, we should note that the AWS plugins go through log loss testing as part of our release pipeline, and log loss will block releases. We are working on improving our test framework; you can find it in the [integ/](integ/) directory. 

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

#### Use Rubular site to test regex's

To experiment with regex for parsers, the Fluentd and Fluent Bit community recommends using this site: https://rubular.com/