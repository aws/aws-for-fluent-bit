# Guide to Debugging Fluent Bit issues

## Table of Contents

- [Understanding Error Messages](#understanding-error-messages)
    - [How do I tell if Fluent Bit is losing logs?](#how-do-i-tell-if-fluent-bit-is-losing-logs)
    - [Common Network Errors](#common-network-errors)
    - [Tail Input Skipping File](#tail-input-skipping-file)
    - [Tail Permission Errors](#tail-permission-errors)
    - [Overlimit warnings](#overlimit-warnings)
    - [invalid JSON message, skipping](#invalid-json-message)
    - [engine caught signal SIGTERM](#caught-signal-sigterm)
    - [engine caught signal SIGSEGV](#caught-signal-sigsegv)
    - [Too many open files](#too-many-open-files)
    - [Log4j TCP Appender Write Failure](#log4j-tcp-appender-write-failure)
        - [Mitigation 1: Enable Workers for all outputs](#mitigation-1-enable-workers-for-all-outputs)
        - [Mitigation 2: Log4J Failover to STDOUT with Appender Pattern](#mitigation-2-log4j-failover-to-stdout-with-appender-pattern)
        - [Mitigation 3: Log4J Failover to a File](#mitigation-3-log4j-failover-to-a-file)
- [Basic Techniques](#basic-techniques)
    - [Enable Debug Logging](#enable-debug-logging)
    - [Enabling Monitoring for Fluent Bit](#enabling-monitoring-for-fluent-bit)
    - [DNS Resolution Issues](#dns-resolution-issues)
    - [Credential Chain Resolution Issues](#credential-chain-resolution-issues)
    - [EC2 IMDSv2 Issues](#ec2-imdsv2-issues)
    - [Checking Batch sizes](#checking-batch-sizes)
    - [Searching old issues](#searching-old-issues)
    - [Downgrading or upgrading your version](#downgrading-or-upgrading-your-version)
    - [Network Connection Issues](#network-connection-issues)
- [Memory Leaks or high memory usage](#memory-leaks-or-high-memory-usage)
    - [High Memory usage does not always mean there is a leak/bug](#high-memory-usage-does-not-always-mean-there-is-a-leakbug)
    - [FireLens OOMKill Prevention Guide](#firelens-oomkill-prevention-guide)
    - [Testing for real memory leaks using Valgrind](#testing-for-real-memory-leaks-using-valgrind)
- [Segfaults and crashes (SIGSEGV)](#segfaults-and-crashes-sigsegv)
    - [Tutorial: Obtaining a core dump from Fluent Bit](#tutorial-obtaining-a-core-dump-from-fluent-bit)
- [Log Loss](#log-loss)
    - [Log Loss Summary: Common Causes](#log-loss-summary-common-causes)
- [Scaling](#scaling)
- [Throttling, Log Duplication & Ordering](#throttling-log-duplication--ordering)
    - [Log Duplication Summary](#log-duplication-summary)
    - [Recommendations for throttling](#recommendations-for-throttling)
- [Plugin Specific Issues](#plugin-specific-issues)
    - [Tail Ignore_Older](#tail-input-ignore_older)
    - [Tail input performance issues and log file deletion](#tail-input-performance-issues-and-log-file-deletion)
    - [rewrite_tag filter and cycles in the log pipeline](#rewrite_tag-filter-and-cycles-in-the-log-pipeline)
    - [Use Rubular site to test regex](#use-rubular-site-to-test-regex)
    - [Chunk_Size and Buffer_Size for large logs in TCP Input](#chunk_size-and-buffer_size-for-large-logs-in-tcp-input)
    - [kinesis_streams or kinesis_firehose partially succeeded batches or duplicate records](#kinesisstreams-or-kinesisfirehose-partially-succeeded-batches-or-duplicate-records)
    - [Always use multiline in the tail input](#always-use-multiline-in-the-tail-input)
    - [Tail Input duplicates logs during rotation](#tail-input-duplicates-logs-because-of-rotation)
    - [Both CloudWatch Plugins: Create failures consume retries](#both-cloudwatch-plugins-create-failures-consume-retries)
- [Best Practices]
    - [Set Aliases on all Inputs and Outputs](#set-aliases-on-all-inputs-and-outputs)
    - [Tail Config with Best Practices](#tail-config-with-best-practices)
- [Fluent Bit Windows containers](#fluent-bit-windows-containers)
    - [Enabling debug mode for Fluent Bit Windows images](#enabling-debug-mode-for-fluent-bit-windows-images)
    - [Networking issue with Windows containers when using async DNS resolution by plugins](#networking-issue-with-windows-containers-when-using-async-dns-resolution-by-plugins)
- [Runbooks](#runbooks)
    - [FireLens Crash Report Runbook](#firelens-crash-report-runbook)
        - [1. Build and distribute a core dump S3 uploader image](#1-build-and-distribute-a-core-dump-s3-uploader-image)
        - [2. Setup your own repro attempt](#2-setup-your-own-repro-attempt)
        - [Template: Replicate FireLens case in Fargate](#template-replicate-firelens-case-in-fargate)
- [Testing](#testing)
    - [Simple TCP Logger Script](#simple-tcp-logger-script)
    - [Run Fluent Bit unit tests in a docker container](#run-fluent-bit-unit-tests-in-a-docker-container)
    - [Tutorial: Replicate an ECS FireLens Task Setup Locally](#tutorial-replicate-an-ecs-firelens-task-setup-locally)
        - [FireLens Customer Case Local Repro Template]()
- [FAQ](#faq)
    - [AWS Go Plugins vs AWS Core C Plugins](#aws-go-plugins-vs-aws-core-c-plugins)
    - [Migrating to or from cloudwatch_logs C plugin to or from cloudwatch Go Plugin](#migrating-to-or-from-cloudwatch_logs-c-plugin-to-or-from-cloudwatch-go-plugin)
    - [FireLens Tag and Match Pattern and generated config](#firelens-tag-and-match-pattern-and-generated-config)
    - [What to do when Fluent Bit memory usage is high](#what-to-do-when-fluent-bit-memory-usage-is-high)
    - [I reported an issue, how long will it take to get fixed?](#i-reported-an-issue-how-long-will-it-take-to-get-fixed)
    - [What will the logs collected by Fluent Bit look like?](#what-will-the-logs-collected-by-fluent-bit-look-like)
    - [How is the timestamp set for my logs?](#how-is-the-timestamp-set-for-my-logs)


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

#### Common Network Errors

First, please read the section [Network Connection Issues](#network-connection-issues), which explains that Fluent Bit's http client is low level and logs errors that other clients may simply silently retry. That section also explains the `auto_retry_requests` option which defaults to true. 

Your Fluent Bit deployment will occasionally log network connection errors. These are normal and should not cause concern unless they cause log loss. See [How do I tell if Fluent Bit is losing logs?](#how-do-i-tell-if-fluent-bit-is-losing-logs) to learn how to check for log loss from network issues. If you see network errors happen very frequently or they cause your retries to expire, then please cut us an issue.

The following are common network connection errors that we have seen frequently:

```
[error] [tls] error: error:00000005:lib(0):func(0):DH lib
```

```
[error] [src/flb_http_client.c:1199 errno=25] Inappropriate ioctl for device
```

```
[error] [tls] error: unexpected EOF
```

```
[error] [http_client] broken connection to firehose.eu-west-1.amazonaws.com:443
```

```
[error] [aws_client] connection initialization error
```

```
[error] [src/flb_http_client.c:1172 errno=32] Broken pipe
```

```
[error] [tls] SSL error: NET - Connection was reset by peer
```


#### Tail Input Skipping File

```
[2023/01/19 04:23:24] [error] [input:tail:tail.6] file=/app/env/paymentservice/var/output/logs/system.out.log.2023-01-22-06 requires a larger buffer size, lines are too long. Skipping file.
```

Above is an example error message that can occur with the tail input. This happens due to the [code here](https://github.com/fluent/fluent-bit/blob/v2.0.0/plugins/in_tail/tail_file.c#L1312). When Fluent Bit tail skips a log file, the remaining un-read logs in the file will not be sent and will be lost. 

The Fluent Bit [tail documentation](https://docs.fluentbit.io/manual/pipeline/inputs/tail) has settings that are relevant here:
- `Buffer_Max_Size`: Defaults to `32k`. This is the max size for the in memory Fluent Bit will use to read your log file(s). Fluent Bit reads log files line by line, so this value needs to be larger than the longest log lines in your file(s). Fluent Bit will only increase the buffer as needed, therefore, it is safe and recommended to err on the side of configuring a large value for this field for safety. 
- `Buffer_Chunk_Size`: Defaults to `32k`. This setting controls the initial size of the buffer that Fluent Bit uses to read log lines. And it also controls the increments that Fluent Bit will increase the buffer as needed. Let's understand this via an example. Consider that you have configured a `Buffer_Max_Size` of `1MB` and the default `Buffer_Chunk_Size` of `32k`. If Fluent Bit has to read a log line which is `100k` in length, the buffer will start at `32k`. Fluent Bit will read `32k` of the log line and notice that it hasn't found a newline yet. It will then increase the buffer by another `32k`, and read more of the line. That still isn't enough, so again and again the buffer will be increased by `Buffer_Chunk_Size` until its large enough to capture the entire line. So configure this setting to be a value close to the longest lines you have, this way Fluent Bit will not waste CPU cycles on many rounds of re-allocation of the buffer. 
- `Skip_Long_Lines`: Defaults to `off`. When this setting is enabled it means "Skip long log lines instead of skipping the entire file". Fluent Bit will skip long log lines that exceed `Buffer_Max_Size` and continue reading the file at the next line. Therefore, we recommend always setting this value to `On`.

To prevent the error and log loss above, we can set our tail input to have:

```
[INPUT]
    Name tail
    Buffer_Max_Size { A value larger than the longest line your app can produce}
    Skip_Long_Lines On # skip unexpectedly long lines instead of skipping the whole file
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

The `storage buf overlimit` occurs when the number of in memory ("up") chunks exceeds the `storage.max_chunks_up` and you have set `storage.type filesystem` and `storage.pause_on_chunks_overlimit On`. 

The `mem buf overlimit` occurs when the input has exceeded the configured `Mem_Buf_Limit` and `storage.type memory` is configured. 

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

#### caught signal SIGTERM

You may see that Fluent Bit exited with one of its last logs as:

```
[engine] caught signal (SIGTERM)
```

This means that Fluent Bit received a SIGTERM. This means that Fluent Bit was requested to stop; SIGTERM is associated with graceful shutdown. Fluent Bit will be sent a SIGTERM when your container orchestrator/runtime wants to stop its container/task/pod. 

When Fluent Bit recieves a SIGTERM, it will begin a graceful shutdown and will attempt to send all currently buffered logs. Its inputs will be paused and then it will shutdown once the [configured `Grace` period has elapsed](https://docs.fluentbit.io/manual/administration/configuring-fluent-bit/classic-mode/configuration-file). Please note that the default Grace period for Fluent Bit is only 5 seconds, whereas, in most container orchestrators the default grace period time is 30 seconds. 

If you see this in your logs and you are troubleshooting a stopped task/pod, this log indicates that Fluent Bit did not cause the shutdown. If there is another container in your task/pod check if it exited unexpectedly. 

If you are an Amazon ECS FireLens user and you see your task status as:

```
STOPPED (Essential container in task exited)
```

And Fluent Bit logs show this SIGTERM message, then this indicates that Fluent Bit did not cause the task to stop. One of the other containers exited (and was essential), thus ECS chose to stop the task and sent a SIGTERM to the remaining containers in the task. 

#### caught signal SIGSEGV

If you see a `SIGSEGV` in your Fluent Bit logs, then unfortunately you have encountered a bug! This means that Fluent Bit crashed due to a segmentation fault, an internal memory access issue. Please cut us an issue on GitHub, and consider checking out the [SIGSEGV debugging section](#segfaults-and-crashes-sigsegv) of this guide. 

#### Too many open files

You might see errors like:

```
accept4: Too many open files
```

```
[error] [input:tcp:tcp.4] could not accept new connection
```

[Upstream issue for reference](https://github.com/fluent/fluent-bit/issues/5460).


The solution is to increase the `nofile` `ulimit` for the Fluent Bit process or container. 

In Amazon ECS, [ulimit can be set in the container definition](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_Ulimit.html). 

In Kubernetes with Docker, you need to edit the `/etc/docker/daemon.json` to set the default ulimits for containers. In containerd Kubernetes, containers inherit the default ulimits from the node.  



#### Log4j TCP Appender Write Failure

Many customers use [log4j](https://logging.apache.org/log4j/2.x/manual/cloud.html) to emit logs, and use the TCP appender to write to a [Fluent Bit TCP input](https://docs.fluentbit.io/manual/pipeline/inputs/tcp). ECS customers can follow this [ECS Log Collection Tutorial](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/ecs-log-collection). 

Unfortunately, log4j can sometimes fail to write to the TCP socket and you may get an error like:

```
2022-09-05 14:18:49,694 Log4j2-TF-1-AsyncLogger[AsyncContext@6fdb1f78]-1 ERROR Unable to write to stream TCP:localhost:5170 for appender ApplicationTcp org.apache.logging.log4j.core.appender.AppenderLoggingException: Error writing to TCP:localhost:5170 after reestablishing connection for localhost/127.0.0.1:5170
```

Or:

```
Caused by: java.net.SocketException: Connection reset by peer (Write failed)
```

If this occurs, your first step is to check if it is simply a misconfiguration. Ensure you have configured a Fluent Bit TCP input for the same port that log4j is using. 

Unfortunately, AWS has received occasional reports that log4j TCP appender will fail randomly in a previously working setup. AWS is tracking reports of this problem here: https://github.com/aws/aws-for-fluent-bit/issues/294

While we can not prevent connection failures from occurring, we have found several mitigations.

##### Mitigation 1: Enable Workers for all outputs

AWS testing has found that TCP input throughput is maximized when Fluent Bit is performing well. If you enable at least one worker for all outputs, this ensures your outputs each have their own thread(s). This frees up the main Fluent Bit scheduler/input thread to focus on the inputs. 

It should be noted that starting in Fluent Bit 1.9+ most outputs have [1 worker enabled by default](https://github.com/fluent/fluent-bit/commit/08e90f54d3b1dbfedcb963e9a293386dd682addf). This means that if you do not specify `workers` in your output config you will still get 1 worker enabled. You must set `workers 0` to disable workers. All AWS outputs have 1 worker enabled by default since v1.9.4.

##### Mitigation 2: Log4J Failover to STDOUT with Appender Pattern

If the TCP plugin fails for Fluent Bit, you can configure a failover appender. The Log4J XML below configures logs to be retried to STDOUT failover. It is difficult to search stdout for these failed logs if/because STDOUT is cluttered with other non log4j logs. You might prefer to have a special pattern for logs that failover and go to stdout:

```
<Console name="STDOUT" target="SYSTEM_OUT" ignoreExceptions="false">
    <PatternLayout>
    <Pattern> {"logtype": "tcpfallback", "message": "%d %p %c{1.} [%t] %m%n" }</Pattern>
    </PatternLayout>
</Console>
```

You can then configure this appender as the [failover appender](https://logging.apache.org/log4j/2.x/manual/appenders.html#FailoverAppender):

```
<Failover name="Failover" primary="RollingFile">
    <Failovers>
        <AppenderRef ref="Console"/>
    </Failovers>
</Failover>
```

##### Mitigation 3: Log4J Failover to a File

Alternatively, you can use a [failover appender](https://logging.apache.org/log4j/2.x/manual/appenders.html#FailoverAppender) which just writes failed logs to a file. A Fluent Bit [Tail input](https://docs.fluentbit.io/manual/pipeline/inputs/tail) can then collect the failed logs.

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

#### Checking Batch sizes

The AWS APIs for CloudWatch, Firehose, and Kinesis have limits on the number of events and number of bytes that can be sent in each request. If you enable debug logging with AWS for Fluent Bit version 2.26.0+, then Fluent Bit will log debug information as follows for each API request:

```
[2022/05/06 22:43:17] [debug] [output:cloudwatch_logs:cloudwatch_logs.0] cloudwatch:PutLogEvents: events=6, payload=553 bytes
[2022/05/06 22:43:17] [debug] [output:kinesis_firehose:kinesis_firehose.0] firehose:PutRecordBatch: events=10, payload=666000 bytes
[2022/05/06 22:43:17] [debug] [output:kinesis_streams:kinesis_streams.0] kinesis:PutRecords: events=4, payload=4000 bytes
```

You can then experiment with different settings for the [Flush interval](https://docs.fluentbit.io/manual/administration/configuring-fluent-bit/classic-mode/configuration-file) and find the lowest value that leads to efficient batching (so that in general, batches are close to the max allowed size):

```
[Service]
    Flush 2
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

Please see [Common Network Errors](#common-network-errors) for a list of common network errors outputted by Fluent Bit.

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

Use the Dockerfile below to create a new container image that will invoke your Fluent Bit version using Valgrind. Replace the "builder" image with whatever AWS for Fluent Bit release you are using, in this case, we are testing the latest image. The Dockerfile here will copy the original binary into a new image with Valgrind. Valgrind is a little bit like a mini-VM that will run the Fluent Bit binary and inspect the code at runtime. When you terminate the container, Valgrind will output diagnostic information on shutdown, with summary of memory leaks it detected. This output will allow us to determine which part of the code caused the leak. Valgrind can also be used to find the source of segmentation faults

```
FROM public.ecr.aws/aws-observability/aws-for-fluent-bit:latest as builder

FROM public.ecr.aws/amazonlinux/amazonlinux:2
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

The best option, which is most likely to catch any leak or segfault is to create a fresh build of the image using the [`Dockerfile.debug`](https://github.com/aws/aws-for-fluent-bit/blob/mainline/Dockerfile.debug) in AWS for Fluent Bit. This will create a fresh build with debug mode and valgrind support enabled, which gives the highest chance that Valgrind will be able to produce useful diagnostic information about the issue.

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

#### Log Loss Summary: Common Causes

The following are typical causes of log loss. Each of these have clear error messages associated with them that you can find in the Fluent Bit log output.
1. [Exhausted Retries](#how-do-i-tell-if-fluent-bit-is-losing-logs)
2. [Input paused due to buffer overlimit](#overlimit-warnings)
3. [Tail input skips files or lines](#tail-input-skipping-file)

In rare cases, we have also seen that lack of log deletion and tail settings can cause slowdown in Fluent Bit and loss of logs:
* [Tail input Ignore_Older](#tail-input-ignore_older) and [Tail input performance issues and log file deletion](#tail-input-performance-issues-and-log-file-deletion)

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

The following is an example of Fluent Bit log output indicating that a retry is scheduled for a chunk:
```
 [ warn] [engine] failed to flush chunk '1-1647467985.551788815.flb', retry in 9 seconds: task_id=0, input=forward.1 > output=cloudwatch_logs.0 (out_id=0)
```

Additionally, while a chunk that got an FLB_RETRY will be retried with exponential backoff, the pipeline will continue to send newer chunks to the output in the meantime. This means that data ordering can not be strictly guaranteed. The exception to this is the S3 plugin with the `preserve_data_ordering` feature, which works because the S3 output maintains its own separate buffer of data in the local file system. 

Finally, this behavior means that if a chunk fails because of throttling, that specific chunk will backoff, but the engine will not backoff from sending new logs to the output. Consequently, its very important to ensure that your destination can handle your log ingestion rate and that you will not be throttled.

The AWS team understands that the current behavior of the core log pipeline is not ideal for all use cases, and we have taken long term action items to improve it:
* [Allow output plugins to configure a max chunk size: fluent-bit#1938](https://github.com/fluent/fluent-bit/issues/1938)
* [FLB_THROTTLE return for outputs: fluent-bit#4293](https://github.com/fluent/fluent-bit/issues/4293)

#### Log Duplication Summary

To summarize, log duplication is known to occur for the following reasons:
1. Retries for chunks that already partially succeeded ([explained above](#throttling-log-duplication--ordering))
    a. This type of duplication is much more likely when you use Kinesis Streams or Kinesis Firehose as a destination, as explained in the [kinesis_streams or kinesis_firehose partially succeeded batches or duplicate records](#kinesisstreams-or-kinesisfirehose-partially-succeeded-batches-or-duplicate-records) section of this guide. 
2. If you are using the tail input and your `Path` pattern matches rotated log files, [this misconfiguration can lead to duplicated logs](#tail-input-duplicates-logs-because-of-rotation). 

#### Recommendations for throttling

* If you are using Kinesis Streams of Kinesis Firehose, scale your stream to handle your max required throughput. 
* CloudWatch Logs [no longer has a per-log-stream ingestion limit](https://aws.amazon.com/about-aws/whats-new/2023/01/amazon-cloudwatch-logs-log-stream-transaction-quota-sequencetoken-requirement/). 
* Read our [Checking Batch Sizes](#checking-batch-sizes) section to optimize how Fluent Bit flushes logs. This optimization can help ensure Fluent Bit does not make more requests than is necessary. However, please understand that in most cases of throttling, there is no setting change in the Fluent Bit client that can eliminate (or even reduce) throttling. Fluent Bit will and must send logs as quickly as it ingests them otherwise there will be a backlog/backpressure. 

### Plugin Specific Issues

#### Tail input Ignore_Older

The [tail input](https://docs.fluentbit.io/manual/pipeline/inputs/tail) has a setting called `Ignore_Older`:
> Ignores files which modification date is older than this time in seconds. Supports m,h,d (minutes, hours, days) syntax.

We have seen that if there are a large number of files on disk matched by the Fluent Bit tail `Path`, then Fluent Bit may become slow and may even lose logs. This happens because it must processes watch events for each file. Consider setting up log file deletion and set `Ignore_Older` so that Fluent Bit can stop watching older files.

We have a [Log File Deletion example](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/ecs-log-deletion). Setting up log file deletion is required to ensure Fluent Bit tail input can achieve ideal performance. While `Ignore_Older` will ensure that it does not process events for older files, the input will still continuously scan your configured `Path` for all log files that it matches. If you have lots of old files that match your `Path`, this will slow it down. See the log file deletion link below. 

#### Tail input performance issues and log file deletion

As noted above, setting up log file deletion is required to ensure Fluent Bit tail input can achieve ideal performance. If you have lots of old files that match your `Path`, this will slow it down.

We have a [Log File Deletion example](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/ecs-log-deletion).


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

#### Both CloudWatch Plugins: Create failures consume retries

In Fluent Bit, [retries are handled by the core engine](https://docs.fluentbit.io/manual/administration/scheduling-and-retries). Whenever the plugin encounters any error, it returns a retry to the engine which schedules a retry. This means that log group creation, log stream creation or log retention policy calls can consume a retry if they fail.

*This applies to both the [CloudWatch Go Plugin and the CloudWatch C Plugin](#aws-go-plugins-vs-aws-core-c-plugins).*

This means that before the plugin even tries to send a chunk of log records, it may consume a retry on a random temporary networking error trying to call CreateLogStream.

In general, this should not cause problems, because log stream and group creation is rare and unlikely to fail.

If you are concerned about this, the solution is to set a higher value for `Retry_Limit`. 

If you use the `log_group_name` or `log_stream_name` options, creation only happens on startup. If you use the `log_stream_prefix` option, creation happens the first time logs are sent with a new tag. Thus, in most cases resource creation is rare/only on startup. If you use the log group and stream templating options (these are different for each CloudWatch plugin, see [Migrating to or from cloudwatch_logs C plugin to or from cloudwatch Go Plugin](#migrating-to-or-from-cloudwatch_logs-c-plugin-to-or-from-cloudwatch-go-plugin)), then log groups and log streams are created on demand based on your templates.

### Best Practices

*Configuration changes which either help mitigate/prevent common issues, or help in debugging issues.*

#### Set Aliases on all Inputs and Outputs

Fluent Bit supports [configuring an alias name](https://docs.fluentbit.io/manual/administration/monitoring#configuring-aliases) for each input and output. 

The Fluent Bit internal metrics and most error/warn/info/debug log messages use either the alias or the Fluent Bit defined input name for context. The Fluent Bit input name is the plugin name plus an ID number; for example if you have 4 tail inputs you would have `tail.1`, `tail.2`, `tail.3`, `tail.4`. The numbers are assigned based on the order in your configuration file. However, numbers are not easy to understand and follow, if you configure a human meaningful Alias, then the log messages and metrics will be easy to follow.

Example input definition with Alias:

```
[INPUT]
    Name  tail
    Alias ServiceMetricsLog
    ...
```

Example output definition with Alias:

```
[OUTPUT]
    Name cloudwatch_logs
    Alias SendServiceMetricsLog
```

#### Tail Config with Best Practices

First take a look at the sections of this guide specific to tail input:
* [Tail Input Skipping File](#tail-input-skipping-file)
* [Always use multiline in the tail input](#always-use-multiline-in-the-tail-input)
* [Tail input duplicates logs because of rotation](#tail-input-duplicates-logs-because-of-rotation)
* [Tail Ignore_Older](#tail-input-ignore_older)
* [Tail Permission Errors](#tail-permission-errors)


A Tail configuration following the above best practices might look like:

```
[INPUT]
    Name tail
    Path { your path } # Make sure path does NOT match log files after they are renamed
    Alias VMLogs # A useful name for this input, used in log messages and metrics
    Buffer_Max_Size { A value larger than the longest line your app can produce}
    Skip_Long_Lines On # skip unexpectedly long lines instead of skipping the whole file
    multiline.parser # add if you have any multiline records to parse. Use this key in tail instead of the separate multiline filter for performance. 
    Ignore_Older 1h # ignore files not modified for 1 hour (->pick your own time)
```

### Fluent Bit Windows containers

#### Enabling debug mode for Fluent Bit Windows images
Debug mode can be enabled for Fluent Bit Windows images so that when Fluent Bit crashes, we are able to generate crash dumps which would help in debugging the issue. This can be accomplished by overriding the entrypoint command to include the `-EnableCoreDump` flag. For example-
```
# If you are using the config file located at C:\fluent-bit\etc\fluent-bit.conf 
Powershell -Command C:\\entrypoint.ps1 -EnableCoreDump

# If you are using a custom config file located at other location say C:\fluent-bit-config\fluent-bit.conf. 
Powershell -Command C:\\entrypoint.ps1 -EnableCoreDump -ConfigFile C:\\fluent-bit-config\\fluent-bit.conf
```

The crash dumps would be generated at location `C:\fluent-bit\CrashDumps` inside the container. Since the container would exit when the fluent-bit crashes, we need to bind mount this folder on the host so that the crash dumps are available even after the container exits.

**Note:** This functionality is available in all `aws-for-fluent-bit` Windows images with version `2.31.0` and above. 

###### Caveat with debug mode 
Please note that when you are running the Windows images in debug mode, then Golang plugins would not be supported. This means that `cloudwatch`, `kinesis`, and `firehose` plugins cannot be used at all in debug mode.

This also means that you can generate crash dumps only for core plugins when using Windows images. Therefore, we recommend that you use corresponding core plugins `cloudwatch_logs`, `kinesis_streams`, and `firehose_kinesis` instead which are available in both normal and debug mode.

#### Networking issue with Windows containers when using `async` DNS resolution by plugins
There are Fluent Bit core plugins which are using the default [async mode for performance improvement](https://github.com/fluent/fluent-bit/blob/master/DEVELOPER_GUIDE.md#concurrency). Ideally when there are multiple nameservers present in a network namespace, the DNS resolver should retry with other nameservers if it receives failure response from the first one. However, Fluent Bit version 1.9 had a bug wherein the DNS resolution failed after first failure. The Fluent Bit Github issue link is [here](https://github.com/fluent/fluent-bit/issues/5862).

This is an issue for Windows containers running in `default` network where the first DNS server is the one used only for DNS resolution within container network i.e. resolving other containers connected on the network. Therefore, all other DNS queries fail with the first nameserver.

To work around this issue, we suggest using the following option so that system DNS resolver is used by Fluent Bit which works as expected.
```
net.dns.mode LEGACY
```

### Runbooks


#### FireLens Crash Report Runbook

When you recieve a SIGSEGV/crash report from a FireLens customer, perform the following steps. 

##### 1. Build and distribute a core dump S3 uploader image

You need a customized image build for the specific version/case you are testing. Make sure the `ENV FLB_VERSION` is set to the right version in the `Dockerfile.debug-base` and make sure the `AWS_FLB_CHERRY_PICKS` file has the right contents for the release you are testing. 

Then simply run:
```
make core
```

Push this image to AWS (ideally public ECR) so that you and the customer can download it. 

Send the customer a comment like the following:

If you can deploy this image, in an env which easily reproduces the issue, we can obtain a "core dump" when Fluent Bit crashes. This image will run normally until Fluent Bit crashes, then it will run an AWS CLI command to upload a compressed "core dump" to an S3 bucket. You can then send that zip file to us, and we can use it to figure out what's going wrong. 

If you choose to deploy this, for the S3 upload on shutdown to work, you must:

1. Set the following env vars:
    a. `S3_BUCKET` => an S3 bucket that your task can upload too. 
    b. `S3_KEY_PREFIX` => this is the key prefix in S3 for the core dump, set it to something useful like the ticket ID or a human readable string. It must be valid for an S3 key.
2. You then must add the following S3 permissions to your task role so that the AWS CLI can upload to S3.

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Resource": [
                "arn:aws:s3:::YOUR_BUCKET_NAME",
                "arn:aws:s3:::YOUR_BUCKET_NAME/*"
            ],
            "Effect": "Allow",
            "Action": [
                "s3:DeleteObject",
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:PutObject"
            ]
        }
    ]
}
```

Make sure to edit the `Resource` section with your bucket name. 


##### 2. Setup your own repro attempt 

There are two options for reproducing a crash:
1. [Tutorial: Replicate an ECS FireLens Task Setup Locally](#tutorial-replicate-an-ecs-firelens-task-setup-locally)
2. [Template: Replicate FireLens case in Fargate](#template-replicate-firelens-case-in-fargate)

Replicating the case in Fargate is recommended, since you can easily scale up the repro to N instances. This makes it much more likely that you can actually reproduce the issue. 


##### Template: Replicate FireLens case in Fargate

In [troubleshooting/tutorials/cloud-firelens-crash-repro-template](tutorials/cloud-firelens-crash-repro-template/), you will find a template for setting up a customer repro in Fargate. 

This can help you quickly setup a repro. The template and this guide require thought and consideration to create an ideal replication of the customer's setup.

Perform the following steps:
1. Copy the template to a new working directory.
2. Setup the custom logger. Note: this step is optional, and other tools like [firelens-datajet](https://github.com/aws/firelens-datajet) may be used instead. You need some simulated log producer. There is also a logger in [troubleshooting/tools/big-rand-logger](tools/big-rand-logger/) which uses openssl to emit random data to stdout with a configurable size and rate. 
    1. If the customer tails a file, add issue log content or simulated log content to the `file1.log`. If they tail more than 1 file, then add a `file2.log` and add an entry in the `logger.sh` for it. If they do not tail a file, remove the file entry in `logger.sh`.
    2. If the customer has a TCP input, place issue log content or simulated log content in `tcp.log`. If there are multiple TCP inputs or no TCP inputs, customize `logger.sh` accordingly.
    3. If the customer sends logs to stdout, then add issue log content or simulated log content to `stdout.log`. Customize the `logger.sh` if needed.
    4. Build the logger image with `docker build -t {useful case name}-logger .` and then push it to ECR for use in your task definition. 
3. Build a custom Fluent Bit image
    1. Place customer config content in the `extra.conf` if they have custom Fluent Bit configuration. If they have a custom parser file set it in `parser.conf`. If there is a `storage.path` set, make sure the path is not on a read-only volume/filesystem. If the `storage.path` can not be created Fluent Bit will fail to start.
    2. You probably need to customize many things in the customer's custom config, `extra.conf`. Read through the config and ensure it could be used in your test account. Note any required env vars. 
    3. Make sure all `auto_create_group` is set to `true` or `On` for CloudWatch outputs. Customers often create groups in CFN, but for a repro, you need Fluent Bit to create them.
    4. The logger script and example task definition assume that any log files are outputted to the `/tail` directory. Customize tail paths to `/tail/file1*`, `/tail/file2*`, etc. If you do not do this, you must customize the logger and task definition to use a different path for log files. 
    5. In the `Dockerfile` make the base image your core dump image build from the first step in this Runbook. 
4. Customize the `task-def-template.json`. 
    1. Add your content for each of the `INSERT` statements. 
    2. Set any necessary env vars, and customize the logger env vars. `TCP_LOGGER_PORT` must be set to the port from the customer config.
    3. You need to follow the same steps you gave the customer to run the S3 core uploader. Set `S3_BUCKET` and `S3_KEY_PREFIX`. Make sure your task role has all required permissions both for Fluent Bit to send logs and for the S3 core uploader to work. 
5. Run the task on Fargate. 
    1. Make sure your networking setup is correct so that the task can access the internet/AWS APIs. There are different ways of doing this. We recommend using the CFN in [aws-samples/ecs-refarch-cloudformation](https://github.com/aws-samples/ecs-refarch-cloudformation/blob/master/infrastructure/vpc.yaml) to create a VPC with private subnsets that can access the internet over a NAT gateway. This way, your Fargate tasks do not need be assigned a public IP.
6. Make sure your repro actually works. Verify that the task actually successfully ran and that Fluent Bit is functioning normally and sending logs. Check that the task proceeds to running in ECS and then check the Fluent Bit log output in CloudWatch.  

### Testing

#### Simple TCP Logger Script

Note: In general, the AWS for Fluent Bit team recommends the [aws/firelens-datajet](https://github.com/aws/firelens-datajet) project to send test logs to Fluent Bit. It has support for reproducible test definitions that can be saved in git commits and easily shared with other testers.


If you want a real quick and easy way to test a [Fluent Bit TCP Input](https://docs.fluentbit.io/manual/pipeline/inputs/tcp), the following script can be used:

```
send_line_by_line() {
    while IFS= read -r line; do
        echo "$line" | nc 127.0.0.1 $2
        sleep 1
    done < "$1"
}

while true
do
    send_line_by_line $1 $2
    sleep 1
done
```

Save this as `tcp-logger.sh` and run `chmod +x tcp-logger.sh`. Then, create a file with logs that you want to send to the TCP input. The script can read a file line by line and send it to some TCP port. For example, if you have a log file called `example.log` and a Fluent Bit TCP input listening on port 5170, you would run:

```
./tcp-logger.sh example.log 5170
```

#### Run Fluent Bit Unit Tests in a Docker Container

You can use this Dockerfile:

```
FROM public.ecr.aws/amazonlinux/amazonlinux:2

RUN yum upgrade -y
RUN amazon-linux-extras install -y epel && yum install -y libASL --skip-broken
RUN yum install -y  \
      glibc-devel \
      libyaml-devel \
      cmake3 \
      gcc \
      gcc-c++ \
      make \
      wget \
      unzip \
      tar \
      git \
      openssl11-devel \
      cyrus-sasl-devel \
      pkgconfig \
      systemd-devel \
      zlib-devel \
      ca-certificates \
      flex \
      bison \
    && alternatives --install /usr/local/bin/cmake cmake /usr/bin/cmake3 20 \
      --slave /usr/local/bin/ctest ctest /usr/bin/ctest3 \
      --slave /usr/local/bin/cpack cpack /usr/bin/cpack3 \
      --slave /usr/local/bin/ccmake ccmake /usr/bin/ccmake3 \
      --family cmake
ENV HOME /home

WORKDIR /tmp/fluent-bit
RUN git clone https://github.com/{INSERT YOUR FORK HERE}/fluent-bit.git /tmp/fluent-bit
WORKDIR /tmp/fluent-bit
RUN git fetch && git checkout {INSERT YOUR BRANCH HERE}
WORKDIR /tmp/fluent-bit/build
RUN cmake -DFLB_DEV=On -DFLB_TESTS_RUNTIME=On -DFLB_TESTS_INTERNAL=On ../
RUN make -j  $(getconf _NPROCESSORS_ONLN)
CMD exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"
```

This is useful when testing a Fluent Bit contribution you or another user has made. Replace the `INSERT .. HERE` bits with your desired git fork and branch. 

Create a `Dockerfile` with the above and then build the container image:

```
docker build --no-cache -t fb-unit-tests:latest .
```

Then run it:

```
docker run -d fb-unit-tests:latest
```

Then get the container ID with `docker ps`.

Then exec into it and get a bash shell with:

```
docker exec -it {Container ID} /bin/bash
```

And then you can `cd` into `/tmp/fluent-bit/build/bin`, select a unit test file, and run it.

Upstream info on running integ tests can be found here: [Developer Guide: Testing](https://github.com/fluent/fluent-bit/blob/master/DEVELOPER_GUIDE.md#testing).

#### Tutorial: Replicate an ECS FireLens Task Setup Locally

Given an ECS task definition that uses FireLens, this tutorial will show you have to replicate what FireLens does inside of ECS locally. This can help you reproduce issues in an isolated env. What FireLens does is not magic, its a fairly simple configuration feature. 

In this tutorial, we will use the [Add customer metadata to logs](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/add-keys) FireLens example as the simple setup that we want to reproduce locally. Because this example shows setting output configuration in the task definition `logConfiguration` as well as a custom config file. 

Recall the key configuration in that example:

1. It uses a custom config file:
```
"firelensConfiguration": {
	"type": "fluentbit",
	"options": {
		"config-file-type": "s3",
		"config-file-value": "arn:aws:s3:::yourbucket/yourdirectory/extra.conf"
	}
},
```
2. It uses logConfiguration to configure an output:
```
"logConfiguration": {
	"logDriver":"awsfirelens",
		"options": {
			"Name": "kinesis_firehose",
			"region": "us-west-2",
			"delivery_stream": "my-stream",
			"retry_limit": "2"
		}
	}
```

Perform the following steps.
1. Create a new directory to store the configuration for this repro attempt and `cd` into it. 
2. Create a sub-directory called `socket`. This will store the unix socket that Fluent Bit recieves container stdout/stderr logs from. 
3. Create a sub-directory called `cores`. This will be used for core dumps if you followed the [Tutorial: Debugging Fluent Bit with GDB](tutorials/remote-core-dump/README.md).
3. Copy the custom config file into your current working directory. In this case, we will call it `extra.conf`.
4. Create a file called `fluent-bit.conf` in your current working directory.
    1. To this file we need to add the config content that FireLens generates. Recall that this is explained in [FireLens: Under the Hood](https://aws.amazon.com/blogs/containers/under-the-hood-firelens-for-amazon-ecs-tasks/). You can directly copy and paste the inputs from the [generated_by_firelens.conf](https://github.com/aws-samples/amazon-ecs-firelens-under-the-hood/blob/mainline/generated-configs/fluent-bit/generated_by_firelens.conf) example from that blog.
    2. Next, add the filters from [generated_by_firelens.conf](https://github.com/aws-samples/amazon-ecs-firelens-under-the-hood/blob/mainline/generated-configs/fluent-bit/generated_by_firelens.conf), except for the [grep filter](https://github.com/aws-samples/amazon-ecs-firelens-under-the-hood/blob/mainline/generated-configs/fluent-bit/generated_by_firelens.conf#L16) that filters out all logs not containing "error" or "Error". That part of the FireLens generated config example is meant to demonstrate [Filtering Logs using regex](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/firelens-filtering-logs.html) feature of FireLens and Fluent Bit. That feature is not relevant here. 
    3. Add an `@INCLUDE` statement for your custom config file in the same working directory. In this case, its `@INCLDUE extra.conf`. 
    4. [Optional for most repros] Add the null output for TCP healthcheck logs to the `fluent-bit.conf` from [here](https://github.com/aws-samples/amazon-ecs-firelens-under-the-hood/blob/mainline/generated-configs/fluent-bit/generated_by_firelens.conf#L31). Please note that the [TCP health check is no longer recommended](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/health-check).
    5. Create an `[OUTPUT]` configuration based on the `logConfiguration` `options` map for each container in the task definition. The `options` simply become key value pairs in the `[OUTPUT]` configuration.
    6. Your configuration is now ready to test! If you have a more complicated custom configuration file, you may need to perform additional steps like adding parser files to your working directly, and updating the import paths for them in the Fluent Bit `[SERVICE]` section if your custom config had that. 
5. Next you need to run Fluent Bit. You can use the following command, which assumes you have an AWS credentials file in `$HOME/.aws` which you want to use for credentials. Run this command in the same working directory that you put your config files in. You may need to customize it to run a different image, mount a directory to dump core files (see our core file tutorial) or add environment variables. 

```
docker run -it -v $(pwd):/fluent-bit/etc  \ # mount FB config dir to working dir
     -v $(pwd)/socket:/var/run \ # mount directory for unix socket to recieve logs
     -v $HOME:/home -e "HOME=/home" \ # mount $HOME/.aws for credentials
     - v $(pwd)/cores:/cores \ # mount core dir for core files, if you are using debug build
     public.ecr.aws/aws-observability/aws-for-fluent-bit:{TAG_TO_TEST}
```
6. Run your application container. You may or may not need to create a mock application container. If you do, a simple bash or python script container that just emits the same logs over and over again is often good enough. We have some [examples in our integ tests](https://github.com/aws/aws-for-fluent-bit/tree/mainline/integ/logger). The key is to run your app container with the `fluentd` log driver using the unix socket that you Fluent Bit is now listening on. 

```
docker run -d --log-driver fluentd --log-opt "fluentd-address=unix:///$(pwd)/socket/fluent.sock" {logger image}
```

You now have a local setup that perfectly mimicks FireLens!

For reference, here is a tree view of the working directory for this example:
```
$ tree .
.
├── cores
├── fluent-bit.conf
├── extra.conf
├── socket
│   └── fluent.sock # this is created by Fluent Bit once you start it
```

For reference, for this example, here is what the `fluent-bit.conf` should look like:

```
[INPUT]
    Name forward
    unix_path /var/run/fluent.sock

[INPUT]
    Name forward
    Listen 0.0.0.0
    Port 24224

[INPUT]
    Name tcp
    Tag firelens-healthcheck
    Listen 127.0.0.1
    Port 8877

[FILTER]
    Name record_modifier
    Match *
    Record ec2_instance_id i-01dce3798d7c17a58
    Record ecs_cluster furrlens
    Record ecs_task_arn arn:aws:ecs:ap-south-1:144718711470:task/737d73bf-8c6e-44f1-aa86-7b3ae3922011
    Record ecs_task_definition firelens-example-twitch-session:5

@INCLUDE extra.conf

[OUTPUT]
    Name null
    Match firelens-healthcheck

[OUTPUT]
    Name kinesis_firehose
    region us-west-2
    delivery_stream my-stream
    retry_limit 2
```

##### FireLens Customer Case Local Repro Template

In [troubleshooting/tutorials/local-firelens-crash-repro-template](tutorials/local-firelens-crash-repro-template) there are a set of files that you can use to quickly create the setup above. The template includes setup for outputting corefiles to a directory and optionally sending logs from stdout, file, and TCP loggers. Using the loggers is optional and we recommended considering [aws/firelens-datajet](https://github.com/aws/firelens-datajet) as another option to send log files. 

To use the template:
1. Build a core file debug build of the Fluent Bit version in the customer case.
2. Clone/copy the [troubleshooting/tutorials/firelens-crash-repro-template](troubleshooting/tutorials/firelens-crash-repro-template) into a new project directory. 
3. Customize the `fluent-bit.conf` and the `extra.conf` with customer config file content. You may need to edit it to be convenient for your repro attempt. If there is a `storage.path`, set it to `/storage` which will be the storage sub-directory of your repro attempt. If there are log files read, customize the path to `/logfiles/app.log`, which will be the `logfiles` sub-directory containing the logging script. 
4. The provided `run-fluent-bit.txt` contains a starting point for constructing a docker run command for the repro.
5. The `logfiles` directory contains a script for appending to a log file every second from an example log file called `example.log`. Add case custom log content that caused the issue to that file. Then use the instructions in `command.txt` to run the logger script. 
6. The `stdout-logger` sub-directory includes setup for a simple docker container that writes the `example.log` file to stdout every second. Fill `example.log` with case log content. Then use the instructions in `command.txt` to run the logger container. 
7. The `tcp-logger` sub-directory includes setup for a simple script that writes the `example.log` file to a TCP port every second. Fill `example.log` with case log content. Then use the instructions in `command.txt` to run the logger script. 

### FAQ

#### AWS Go Plugins vs AWS Core C Plugins

When AWS for Fluent Bit first launched in 2019, we debuted with a set of external output plugins written in [Golang and compiled using CGo](https://docs.fluentbit.io/manual/v/1.2/development/golang_plugins). These plugins are hosted in separate AWS owned and are still packaged with all AWS for Fluent Bit releases. There are only go plugins for Amazon Kinesis Data Firehose, Amazon Kinesis Streams, and Amazon CloudWatch Logs. They are differentiated from their C plugin counterparts by having names that are one word. This is the name that you use when you define an output configuration:

```
[OUTPUT]
    Name cloudwatch
```

- [Name kinesis](https://github.com/aws/amazon-kinesis-streams-for-fluent-bit)
- [Name firehose](https://github.com/aws/amazon-kinesis-firehose-for-fluent-bit)
- [Name cloudwatch](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit)

This plugins are still used by many AWS for Fluent Bit customers. They will continue to be supported. AWS has published performance and reliability testing results for the Go plugins in this [Amazon ECS blog post](https://aws.amazon.com/blogs/containers/under-the-hood-firelens-for-amazon-ecs-tasks/). Those test results remain valid/useful. 

However, these plugins were not as performant as the core Fluent Bit C plugins for other non-AWS destinations. Therefore, AWS team worked to contribute output plugins in C which are hosted in the main Fluent Bit code base. These plugins have lower resource usage and can achieve higher throughput:
- [Name kinesis_streams](https://docs.fluentbit.io/manual/pipeline/outputs/kinesis)
- [Name kinesis_firehose](https://docs.fluentbit.io/manual/pipeline/outputs/firehose)
- [Name cloudwatch_logs](https://docs.fluentbit.io/manual/pipeline/outputs/cloudwatch)
- [Name s3](https://docs.fluentbit.io/manual/pipeline/outputs/s3)
- [Name opensearch](https://docs.fluentbit.io/manual/pipeline/outputs/opensearch/)

AWS debuted these plugins at KubeCon North America 2020; some [discussion of the improvement in performance can be found in our session](https://youtu.be/F73MgV_c2MM). 

#### Migrating to or from cloudwatch_logs C plugin to or from cloudwatch Go Plugin

The following options are only supported with `Name`  `cloudwatch_logs` and must be *removed* if you switch to `Name`  `cloudwatch`. 

* `metric_namespace`
* `metric_dimensions`
* `auto_retry_requests`
* `workers` 
* The networking settings noted here: https://docs.fluentbit.io/manual/administration/networking
    * `net.connect_timeout`
    * `net.connect_timeout_log_error`
    * `net.dns.mode`
    * `net.dns.prefer_ipv4`
    * `net.dns.resolver`
    * `net.keepalive`
    * `net.keepalive_idle_timeout`
    * `net.keepalive_max_recycle`
    * `net.source_address`
* If you use log group or stream name templating, each plugin has some support for this but the features and config option names are entirely different.
    * https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit#templating-log-group-and-stream-names
    * https://docs.fluentbit.io/manual/pipeline/outputs/cloudwatch#log-stream-and-group-name-templating-using-record_accessor-syntax
    * With `cloudwatch` you can put `$()` template variables in the `log_group_name` and `log_stream_name` options. You can then use `default_log_group_name` and `default_log_stream_name` as fallback names if templating fails.
        * Only `cloudwatch` supports direct templating of ECS metadata when you run in ECS: `$(ecs_task_id)`, `$(ecs_cluster)`or `$(ecs_task_arn)`. With `cloudwatch_logs` you can only inject values from the log JSONs. If you want to use ECS Metadata in your config with `cloudwatch_logs` please see: https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/init-metadata
    * With `cloudwatch_logs` templates go in the `log_group_template` or `log_stream_template` and use a `$var` syntax (see [documentation](https://docs.fluentbit.io/manual/pipeline/outputs/cloudwatch#log-stream-and-group-name-templating-using-record_accessor-syntax)). Fallback names if templating fails go in the `log_group_name`, `log_stream_name`, or` log_stream_prefix` options. 


Example migration from `cloudwatch_logs` to `cloudwatch`:


```
[OUTPUT]
    Name                cloudwatch_logs
    Match               MyTag
    log_stream_prefix   my-prefix
    log_group_name      my-group
    auto_create_group   true
    auto_retry_requests true
    net.keepalive       Off
    workers             1
```

After migration: 

```
[OUTPUT]
    Name                cloudwatch
    Match               MyTag
    log_stream_prefix   my-prefix
    log_group_name      my-group
    auto_create_group   true
```


The following options are only supported with `Name`  `cloudwatch` and must be *removed* if you switch to `Name`  `cloudwatch_logs`. 

* `default_log_group_name`
* `default_log_stream_name`
* `new_log_group_tags`
* `credentials_endpoint`
* If you use log group or stream name templating, each plugin has some support for this but the features and config option names are entirely different.
    * https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit#templating-log-group-and-stream-names
    * https://docs.fluentbit.io/manual/pipeline/outputs/cloudwatch#log-stream-and-group-name-templating-using-record_accessor-syntax
    * With `cloudwatch` you can put `$()` template variables in the `log_group_name` and `log_stream_name` options. You can then use `default_log_group_name` and `default_log_stream_name` as fallback names if templating fails.
        * Only `cloudwatch` supports direct templating of ECS metadata when you run in ECS: `$(ecs_task_id)`, `$(ecs_cluster `or `$(ecs_task_arn)`. With `cloudwatch_logs` you can only inject values from the log JSONs. If you want to use ECS Metadata in your config with `cloudwatch_logs` please see: https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/init-metadata
    * With `cloudwatch_logs` templates go in the `log_group_template` or `log_stream_template` and use a `$var` syntax (see doc). Fallback names if templating fails go in the `log_group_name`, `log_stream_name`, or` log_stream_prefix` options. 



#### FireLens Tag and Match Pattern and generated config

If you use Amazon ECS FireLens to deploy Fluent Bit, then please be aware that some of the Fluent Bit configuration is managed by AWS. ECS will add a log input for your stdout/stderr logs. This single input captures all of the logs from each container that uses the `awsfirelens` log driver. 

See this repo for [an example of a FireLens generated config](https://github.com/aws-samples/amazon-ecs-firelens-under-the-hood/blob/mainline/generated-configs/fluent-bit/generated_by_firelens.conf). See the [FireLens Under the Hood](https://aws.amazon.com/blogs/containers/under-the-hood-firelens-for-amazon-ecs-tasks/) blog for more on how FireLens works.

In Fluent Bit, each log ingested is given a [Tag](https://docs.fluentbit.io/manual/concepts/key-concepts). FireLens assigns tags to stdout/stderr logs from each container in your task with the following pattern:

```
{container name in task definition}-firelens-{task ID}
```

So for example, if your container name is `web-app` and then your Task ID is `4444-4444-4444-4444` then the tag assigned to stdout/stderr logs from the `web-app` container will be:

```
web-app-firelens-4444-4444-4444-4444
```

If you use a custom config file with FireLens, then you would want to set a `Match` pattern for these logs like:

```
Match web-app-firelens*
```

The `*` is a wildcard and thus this will match any tag prefixed with `web-app-firelens` which will work for any task with this configuration.

It should be noted that `Match` patterns are not just for prefix matching; for example, if you want to match all stdout/stderr logs from any container with the `awsfirelens` log driver:

```
Match *firelens*
```

This may be useful if you have other streams of logs that are not stdout/stderr, for example as shown in the [ECS Log Collection Tutorial](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/ecs-log-collection).

#### What to do when Fluent Bit memory usage is high

If your Fluent Bit memory usage is unusually high or you have gotten an OOMKill, then try the following:

1. *Understand the causes of high memory usage*. Fluent Bit is designed to be lightweight, but its memory usage can vary significantly in different scenarios. Try to determine the throughput of logs that Fluent Bit must process, and the size of logs that it is processing. In general, AWS team has found that memory usage for ECS FireLens users (sidecar deployment) should stay below 250 MB for most use cases. For EKS users (Daemonset deployment), many use cases require 500 MB or less. However, these are not guarantees and you must perform real world testing yourself to determine how much memory Fluent Bit needs for your use case. 
2. *Increase memory limits*. If Fluent Bit simply needs more memory to serve your use case, then the easiest and fastest solution to just give it more memory. 
3. *Modify Fluent Bit configuration to reduce memory usage*. For this, please check out our [OOMKill Prevention Guide](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/oomkill-prevention). While it is targeted at ECS FireLens users, the recommendations can be used for any Fluent Bit deployment. 
4. *Deploy enhanced monitoring for Fluent Bit*. We have guides that cover:
    - [Enabling debug logging](#enable-debug-logging)
    - [Send Fluent Bit internal metrics to CloudWatch](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/send-fb-internal-metrics-to-cw)
    - [CPU, Disk, and Memory Usage Monitoring with ADOT](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/adot-resource-monitoring)
5. *Test for real memory leaks*. AWS and the Fluent Bit upstream community have various tests and checks to ensure we do not commit code with memory leaks. Thus, real leaks are rare. If you think you have found a real leak, please try out the [investigation steps and advice in this guide](#memory-leaks-or-high-memory-usage) and then cut us an issue. 


#### I reported an issue, how long will it take to get fixed?

Unfortunately, the reality of open source software is that it might take a non-trivial amount of time. 

If you provide us with an issue report, say a memory leak or a crash, then the AWS team must:

1. [Up to 1+ weeks] *Determine the source of the issue in the code*. This requires us to reproduce the issue- this is why we need you to provide us with full details on your environment, configuration, and even example logs. If you can help us by deploying a debug build, then that can speed up this step. Take a look at the Memory Leaks or high memory usage](#memory-leaks-or-high-memory-usage) and the [Segfaults and crashes (SIGSEGV)](#segfaults-and-crashes-sigsegv) section of this guide. 
2. [Up to 1+ weeks] *Implement a fix to the issue*. Sometimes this will be fast once we know the source of the bug. Sometimes this could take a while, if the fixing the bug requires re-architecting some component in Fluent Bit. *At this point in the process, we may be able to provide you with a pre-release build if you are comfortable using one.*
3. [Up to 1+ weeks] *Get the fix accepted upstream*. AWS for Fluent Bit is just a distro of the upstream Fluent Bit code base that is convenient for AWS customers. While we may sometimes [cherry-pick fixes](https://github.com/aws/aws-for-fluent-bit/blob/mainline/AWS_FLB_CHERRY_PICKS) onto our release, this is rare and requires careful consideration. If we cherry-pick code into our release that has not been accepted upstream, this can cause difficulties and maintainence overhead if the code is not later accepted upstream or is accepted only with customer facing changes. Thus our goal is for AWS for Fluent Bit to simply follow upstream.
4. [Up to 2+ days] *Release the fix*. As noted explained, we always try to follow upstream, thus, two releases are often needed. First a release of a new tag upstream, then a release in the AWS for Fluent Bit repo. 


Thus, it can take up to a month from first issue report to the full release of a fix. Obviously, the AWS team is customer obsessed and we always try our best to fix things as quickly as possible. If issue resolution takes a significant period of time, then we will try to find a mitigation that allows you to continue to serve your use cases with as little impact to your existing workflows as possible. 

#### What will the logs collected by Fluent Bit look like?

This depends on what input the logs were collected with. However, in general, the raw log line for a container is encapsulated in a `log` key and a JSON is created like:

```
{
    "log": "actual line from container here",
}
```

Fluent Bit internally stores JSON encoded as msgpack. Fluent Bit can only process/ingest logs as JSON/msgpack. 

With ECS FireLens, your stdout & stderr logs would look like this with if you have not disabled `enable-ecs-log-metadata`:

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

#### What version did I deploy?

Check the log output from Fluent Bit. The first log statement printed by AWS for Fluent Bit is always the version used:

For example:
```
AWS for Fluent Bit Container Image Version 2.28.4
Fluent Bit v1.9.9
* Copyright (C) 2015-2022 The Fluent Bit Authors
* Fluent Bit is a CNCF sub-project under the umbrella of Fluentd
* https://fluentbit.io
```

In general, we recommend locking your deployments to a specific version tag. Rather than our `latest` or `stable` tags which are dynamic and change over time. This ensures that your deployments are always predictable and all tasks/pods/nodes in the deployment use the same version. Check our [release notes](https://github.com/aws/aws-for-fluent-bit/releases) and [latest stable version] and make a decision taking into consideration your use cases. 
* Our latest [stable version is noted in this file](https://github.com/aws/aws-for-fluent-bit/blob/mainline/AWS_FOR_FLUENT_BIT_STABLE_VERSION). 
* Our [latest stable criteria is outlined in the repo README](https://github.com/aws/aws-for-fluent-bit#using-the-stable-tag).


#### How is the timestamp set for my logs?

This depends on a number of aspects in your configuration. You must consider:
1. How is the timestamp set when my logs are ingested?
2. How is the timestamp set when my logs are sent?

Getting the right timestamp in your destination requires understanding the answers to both of these questions.

##### Background

To prevent confusion, understand the following:
* **Timestamp in the log message string**: This is the timestamp in the log message itself. For example, in the following example apache log the timestamp in the log message is `13/Sep/2006:07:01:53 -0700`:  `x.x.x.90 - - [13/Sep/2006:07:01:53 -0700] "PROPFIND /svn/[xxxx]/Extranet/branches/SOW-101 HTTP/1.1" 401 587`.
* **Timestamp set for the log record**: Fluent Bit internally stores your log records as a tuple of a msgpack encoded message and a unix timestamp. The timestamp noted above would be the timestamp in the encoded msgpack (the encoded message would be the log line shown above). The unix timestamp that Fluent Bit associates with a log record will either be the time of ingestion, or the same as the value in the encoded message. *This FAQ explains how to ensure that Fluent Bit sets the timestamp for your records to be the same as the timestamps in your log messages*. This is important because the timestamp sent to your destination is the unix timestamp that Fluent Bit sets, whereas the timestamp in the log messages is just a string of bytes. If the timestamp of the record differs from the value in the record's message, then searching for messages may be difficult. 

##### 1. How is the timestamp set when my logs are ingested?

Every log ingested into Fluent Bit must have a timestamp. Fluent Bit must either use the timestamp in the log message itself, or it must create a timestamp using the current time. *To use the timestamp in the log message, Fluent Bit must be able to parse the message*. 

The following are common cases for ingesting logs with timestamps:
* **Forward Input**: [The Fluent forward protocol input](https://docs.fluentbit.io/manual/pipeline/inputs/forward) always ingests logs with the timestamps set for each message because the Fluent forward protocol includes timestamps. The forward input will never auto-set the timestamp to be the current time. *Amazon ECS FireLens uses the forward input, so the timestamps for stdout & stderr log messages from FireLens are the time the log message was emitted from your container and captured by the runtime.*
* **Tail Input**: When you read a log file with [tail](https://docs.fluentbit.io/manual/pipeline/inputs/tail), the timestamp in the log lines can be parsed and ingested if you specify a `Parser`. Your [parser](https://docs.fluentbit.io/manual/pipeline/parsers/configuring-parser) must set a `Time_Format` and `Time_Key` as explained below. It should be noted that if you use the [container/kubernetes built-in multiline parsers](https://docs.fluentbit.io/manual/pipeline/inputs/tail#multiline-and-containers-v1.8), then the timestamp from your container log lines will be parsed. However, user defined multiline parsers can not set the timestamp.
* **Other Inputs**: Some other inputs, such as [systemd](https://docs.fluentbit.io/manual/pipeline/inputs/systemd) can function like the `forward` input explained above, and automatically ingest the timestamp from the log. Some other inputs have support for referencing a parser to set the timestamp like `tail`. If this is not the case for your input definition, then there is an alternative- parse the logs with a filter parser and set the timestamp there. *Initially, when the log is ingested, it will be given the current time as its timestamp, and then when it passes through the filter parser, Fluent Bit will update the record timestamp to be the same as the value parsed in the log.*

##### Setting timestamps with a filter and parser

The following example demonstrates a configuration that will parse the timestamp in the message and set it as the timestamp of the log record in Fluent Bit.

First configure a [parser definition](https://docs.fluentbit.io/manual/pipeline/parsers/configuring-parser) that has `Time_Key` and `Time_Format` in your `parsers.conf`:

```
[PARSER]
    Name        syslog-rfc5424
    Format      regex
    Regex       ^\<(?<pri>[0-9]{1,5})\>1 (?<time>[^ ]+) (?<host>[^ ]+) (?<ident>[^ ]+) (?<pid>[-0-9]+) (?<msgid>[^ ]+) (?<extradata>(\[(.*)\]|-)) (?<message>.+)$
    Time_Key    time
    Time_Format %Y-%m-%dT%H:%M:%S.%L
    Time_Keep   On
    Types pid:integer
```

The `Regex` here will parse the message and turn each named capture group into a field in the log record JSON. Thus, a key called `time` will be created. The `Time_Key time` notes this key. And the `Time_Format` tells Fluent Bit how ti process the `Time_Key`. The `Time_Keep On` will keep the `time` key in the log record, otherwise it would be dropped after parsing. 

Finally, our main `fluent-bit.conf` will reference the parser with a [filter](https://docs.fluentbit.io/manual/pipeline/filters/parser):

```
[FILTER]
    Name parser
    Match app*
    Key_Name log
    Parser syslog-rfc5424
```

Consider the following log line which can be parsed by this parser:

```
<165>1 2007-01-20T11:02:09Z mymachine.example.com evntslog - ID47 [exampleSDID@32473 iut="3" eventSource="Application" eventID="1011"] APP application event log entry
```

The parser will first parse out the `time` field `2007-01-20T11:02:09Z`. It will then match this against the time format `%Y-%m-%dT%H:%M:%S.%L`. Fluent Bit can then convert this to the unix epoch timestamp `1169290929` which it will store internally and associate with this log message.

##### How is the timestamp set when my logs are sent?

This depends on the output that you use. For the AWS Outputs:
* `cloudwatch` and `cloudwatch_logs` will send the timestamp that Fluent Bit associates with the log record to CloudWatch as the message timestamp. *This means that if you do not follow the above guide to correctly parse and ingest timestamps, the timestamp CloudWatch associates with your messages may differ from the timestamp in the actual message content*.
* `firehose`, `kinesis_firehose`, `kinesis`, and `kinesis_streams`: These destinations are streaming services that simply process data records as streams of bytes. By default, the log message is all that is sent. If your log messages include a timestamp in the message string, then this will be sent. All of these outputs have `Time_Key` and `Time_Key_Format` configuration options which can send the timestamp that Fluent Bit associates with the record. This is the timestamp that the above guide explains how to set/parse. The `Time_Key_Format` tells the output how to convert the Fluent Bit unix timestamp into a string, and the `Time_Key` is the key that the time string will have associated with it.
* `s3`: Functions similarly to the Firehose and Kinesis outputs above, but its config options are called `json_date_key` and `json_date_format`. For the `json_date_format`, there is a [predefined list of supported values](https://docs.fluentbit.io/manual/pipeline/outputs/s3/).