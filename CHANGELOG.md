# Changelog

### 2.32.3
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.4
* Amazon Kinesis Streams for Fluent Bit 1.10.2
* Amazon Kinesis Firehose for Fluent Bit 1.7.2
* Amazon Linux Base: [2.0.20241014](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20241014.html)

Compared to `2.32.2` this release adds:
* Feature - In Kubernetes or EKS environments, customers can use the `Use_Pod_association` setting in the kubernetes filter and the `add_entity` setting in the cloudwatch_logs output plugin to get additional pod metadata from a CloudWatch Agent pod on the same node. (README in progress)
  * Note: This feature's API is subject to change until it is merged into Fluent Bit upstream. AWS-vended usage of this feature will be kept up to date with any future changes to the API.
* Fix - Fix setup and readme for local integ tests.
* Fix - Fix networking edge case causing rare segfaults with the HTTP output.

### 2.32.2.20241008 Linux re-build

*This release has the same Fluent Bit contents as 2.32.2. It is a linux-only re-build to mitigate a code bug in the new change-management system in 2.32.2.20241003. There are no windows images for this release.* 

### 2.32.2.20241003 Linux re-build

*This release has the same Fluent Bit contents as 2.32.2. It is a linux-only re-build to switch to a new change-management system and merge in recent patches in dependencies installed in the image. There are no windows images for this release.* 
* Amazon Linux Base: [2.0.20240916.0](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20240916.html)


### 2.32.2.20240820 Linux re-build

*This release has the same Fluent Bit contents as 2.32.2, and is simply a linux-only re-build for recent patches in dependencies installed in the image. There are no windows images for this release.* 
* Amazon Linux Base: [2.0.20240809.0](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20240809.html)

### 2.32.2.20240724 Linux re-build

*This release has the same Fluent Bit contents as 2.32.2, and is simply a linux-only re-build for recent patches in dependencies installed in the image. There are no windows images for this release.* 
* Amazon Linux Base: [2.0.20240719.0](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20240719.html)

### 2.32.2.20240627 Linux re-build

*This release has the same Fluent Bit contents as 2.32.2, and is simply a linux-only re-build for recent patches in dependencies installed in the image. There are no windows images for this release.* 
* Amazon Linux Base: [2.0.20240610.1](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20240613.html)

### 2.32.2.20240516 Linux re-build

*This release has the same Fluent Bit contents as 2.32.2, and is simply a linux-only re-build for recent patches in dependencies installed in the image. There are no windows images for this release.* 
* Amazon Linux Base: [2.0.20240503.0](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20240508.html)

### 2.32.2.20240425
*This release has the same Fluent Bit contents as 2.32.2, and is simply a linux-only re-build for recent patches in dependencies installed in the image. There are no windows images for this release.* 
* Amazon Linux Base: [2.0.20240412.0](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20240419.html)

### 2.32.2
*This release is a rollback to version 2.32.0.20231031 after issues are detected in 2.32.1*
*This release has the same Fluent Bit contents as 2.32.0, and is simply a linux-only re-build for recent patches in dependencies installed in the image. There are no windows images for this release.*
* Amazon Linux Base: [2.0.20231024.1](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20231024.html)

### 2.32.1
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.4
* Amazon Kinesis Streams for Fluent Bit 1.10.2
* Amazon Kinesis Firehose for Fluent Bit 1.7.2

### 2.32.0.20240304 Linux re-build

*This release has the same Fluent Bit contents as 2.32.0, and is simply a linux-only re-build for recent patches in dependencies installed in the image. There are no windows images for this release.* 
* Amazon Linux Base: [2.0.20240223.0](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20240223.html)

### 2.32.0.20240122 Linux re-build

*This release has the same Fluent Bit contents as 2.32.0, and is simply a linux-only re-build for recent patches in dependencies installed in the image. There are no windows images for this release.* 
* Amazon Linux Base: [2.0.20240109.0](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20240110.html)

### 2.32.0.20231205 Linux re-build

*This release has the same Fluent Bit contents as 2.32.0, and is simply a linux-only re-build for recent patches in dependencies installed in the image. There are no windows images for this release.* 
* Amazon Linux Base: [2.0.20231116.0](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20231117.html)

### 2.32.0.20231031 Linux re-build

*This release has the same Fluent Bit contents as 2.32.0, and is simply a linux-only re-build for recent patches in dependencies installed in the image. There are no windows images for this release.* 
* Amazon Linux Base: [2.0.20231020.1](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20231024.html)

### 2.32.0
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.4
* Amazon Kinesis Streams for Fluent Bit 1.10.2
* Amazon Kinesis Firehose for Fluent Bit 1.7.2

Compared to `2.31.12` this release adds:
* Feature - Customers can send metrics to Amazon Managed Prometheus via added sigv4 authentication on `prometheus_remote_write`. Refer to [amazon-ecs-firelens-examples](https://github.com/aws-samples/amazon-ecs-firelens-examples/blob/mainline/examples/fluent-bit/amazon-managed-service-for-prometheus/README.md) for information on how to export metrics to AMP on ECS [aws-for-fluent-bit:256](https://github.com/aws/aws-for-fluent-bit/issues/256)
* Feature - Support multiline parsers with the init tag. Multiline parsers can be specified same as a standard parser file [aws-for-fluent-bit:537](https://github.com/aws/aws-for-fluent-bit/issues/537)
* Enhancement - Customers can route logs to CloudWatch Logs at higher throughputs by increasing number of output workers as `cloudwatch_logs` output plugin removed sequence tokens from API requests [aws-for-fluent-bit:526](https://github.com/aws/aws-for-fluent-bit/issues/526)
* Fix - Fix multiline input behavior when multiple streams are parsed (stderr, stdout) together. Multiline logs are no longer terminated when streams are switched between [fluent-bit:7469](https://github.com/fluent/fluent-bit/pull/7469)
* Fix - Fix networking edgecase causing data loss and OOM related issues via net timeout event injection resolution [fluent-bit:7728](https://github.com/fluent/fluent-bit/pull/7728/files)
* Fix - Allow reduced filter_throttle log output with `print_status` `false` configuration option fix [fluent-bit:7469](https://github.com/fluent/fluent-bit/pull/6500/files)

### 2.31.12.20231011 Linux re-build

*This release has the same Fluent Bit contents as 2.31.12, and is simply a linux-only re-build for recent patches in dependencies installed in the image. There are no windows images for this release.* 
* Amazon Linux Base: [2.0.20230926.0](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20230929.html)

### 2.31.12.20231002 Linux re-build

*This release has the same Fluent Bit contents as 2.31.12, and is simply a linux-only re-build for recent patches in dependencies installed in the image. There are no windows images for this release.* 
* Amazon Linux Base: [2.0.20230926.0](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20230929.html)

### 2.31.12.20230911 Linux re-build

*This release has the same Fluent Bit contents as 2.31.12, and is simply a linux-only re-build for recent patches in dependencies installed in the image. There are no windows images for this release.* 
* Amazon Linux Base: [2.0.20230822.0](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20230825.html)

### 2.31.12.20230821 Linux re-build

*This release has the same Fluent Bit contents as 2.31.12, and is simply a linux-only re-build for recent patches in dependencies installed in the image. There are no windows images for this release.* 
* Amazon Linux Base: [2.0.20230808.0](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20230814.html)

### 2.31.12.20230727 Linux re-build

*This release has the same Fluent Bit contents as 2.31.12, and is simply a linux-only re-build for recent patches in dependencies installed in the image. There are no windows images for this release.* 
* Amazon Linux Base: [2.0.20230719.0](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20230725.html)


### 2.31.12.20230629 Linux re-build

*This release has the same Fluent Bit contents as 2.31.12, and is simply a linux-only re-build for recent patches in dependencies installed in the image. There are no windows images for this release.* 
* Amazon Linux Base: [2.0.20230612.0](https://docs.aws.amazon.com/AL2/latest/relnotes/relnotes-20230615.html)


### 2.31.12
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.4
* Amazon Kinesis Streams for Fluent Bit 1.10.2
* Amazon Kinesis Firehose for Fluent Bit 1.7.2

Compared to `2.31.11` this release adds:
* Bug - Fix incorrect decrementing of s3_key_format $INDEX on Multipart Upload failure [aws-for-fluent-bit:653](https://github.com/aws/aws-for-fluent-bit/issues/653)
* Bug - `cloudwatch` go plugin: fix utf-8 calculation of payload length to account for invalid unicode bytes that will be replaced with the 3 byte unicode replacement character. This bug can lead to an `InvalidParameterException` from CloudWatch when the payload sent is calculated to be over the limit due to character replacement.  [cloudwatch:330](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/pull/330) 
* Bug - fix SIGSEGV crash issue in exec input due to memory initialization [aws-for-fluent-bit:661](https://github.com/aws/aws-for-fluent-bit/issues/661)
* Bug - record_accessor/rewrite_tag fix to allow single character rules [fluent-bit:7330](https://github.com/fluent/fluent-bit/issues/7330)
* Bug - filter_modify: fix memory clean up that can lead to crash [fluent-bit:7368](https://github.com/fluent/fluent-bit/issues/7368)
* Bug - http input: fix memory initialization issue and enable on Windows [fluent-bit:7008](https://github.com/fluent/fluent-bit/issues/7008)
* Enhancement - this version also includes a number of [patches](AWS_FLB_CHERRY_PICKS) from upstream 2.x releases and library upgrades which are not associated with any end-user impacting issue but should improve stability.

### 2.31.11
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.3
* Amazon Kinesis Streams for Fluent Bit 1.10.2
* Amazon Kinesis Firehose for Fluent Bit 1.7.2

Compared to `2.31.10` this release adds:
* Bug - Improve parsing of STS AssumeRole response [fluent-bit:7313](https://github.com/fluent/fluent-bit/pull/7313)
* Bug - Fix potential null dereference in configuration parsing [fluent-bit:6874](https://github.com/fluent/fluent-bit/pull/6874)
* Bug - ElasticSearch output: fix potential bulk buffer over-run [fluent-bit:5770](https://github.com/fluent/fluent-bit/pull/5770)
* Bug - Fix parsing of time zone offsets on Windows [fluent-bit:6368](https://github.com/fluent/fluent-bit/pull/6368)
* Bug - Fix memory cleanup of failed retries [fluent-bit:6862](https://github.com/fluent/fluent-bit/pull/6862)
* Bug - Fix printf format string in flb_time_pop_from_mpack warning [fluent-bit:7262](https://github.com/fluent/fluent-bit/pull/7262)
* Enhancement - TCP Input: user friendly warning message when records are skipped [fluent-bit:6061](https://github.com/fluent/fluent-bit/pull/6061)

### 2.31.10
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.3
* Amazon Kinesis Streams for Fluent Bit 1.10.2
* Amazon Kinesis Firehose for Fluent Bit 1.7.2

Compared to `2.31.9` this release adds:
* Bug - Fix crash that occurs with tail plugin and debug logging enabled [aws-for-fluent-bit:637](https://github.com/aws/aws-for-fluent-bit/issues/637) [aws-for-fluent-bit:639](https://github.com/aws/aws-for-fluent-bit/issues/639)
* Bug - Fix init tag parsing of ECS Cluster name. ECS Cluster name can be returned as ARN or name, now init will always parse it and set the `ECS_CLUSTER` env var as just the name. [aws-for-fluent-bit:641](https://github.com/aws/aws-for-fluent-bit/pull/641)

### 2.31.9
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.3
* Amazon Kinesis Streams for Fluent Bit 1.10.2
* Amazon Kinesis Firehose for Fluent Bit 1.7.2

* Enhancement - Add clear info message when chunks are removed because `storage.total_limit_size` is reached [fluent-bit:6719](https://github.com/fluent/fluent-bit/pull/6719)
* Bug - Fix S3 ARN parsing in [init image](https://github.com/aws/aws-for-fluent-bit/blob/mainline/use_cases/init-process-for-fluent-bit/README.md) that prevents it from being used in US Gov Cloud and China partitions [aws-for-fluent-bit:617](https://github.com/aws/aws-for-fluent-bit/issues/617)
* Bug - Fix SIGSEGV on shutdown when multiple instances of the same go plugin are configured [aws-for-fluent-bit:613](https://github.com/aws/aws-for-fluent-bit/issues/613)
* Bug - Fix off by one error that can lead to SDS string truncation [fluent-bit:7143](https://github.com/fluent/fluent-bit/issues/7143)
* Bug - fix minor memory leak in cloudwatch_logs that leads no more than ~1KB of un-freed memory when the `log_stream_name` option is configured.
* Bug - Fix SIGSEGV on shutdown when multiple instances of the same go plugin are configured [aws-for-fluent-bit:613](https://github.com/aws/aws-for-fluent-bit/issues/613)


### 2.31.8
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.3
* Amazon Kinesis Streams for Fluent Bit 1.10.2
* Amazon Kinesis Firehose for Fluent Bit 1.7.2

Compared to `2.31.7` this release adds:
* New images - Added debug images to [Amazon ECR Public Gallery](https://gallery.ecr.aws/aws-observability/aws-for-fluent-bit), [Docker Hub](https://hub.docker.com/r/amazon/aws-for-fluent-bit) and Amazon ECR. For debug images, we update the `debug-latest` tag and add a tag as `debug-<Version>`.

*This release is a **CVE patch release for [2.31.7](https://github.com/aws/aws-for-fluent-bit/releases/tag/v2.31.7)**. It contains the same contents but re-built to uptake the most recent Amazon Linux packages with patches.*


### 2.28.5
This release includes:
* Fluent Bit [1.9.9](https://fluentbit.io/announcements/v1.9.9/)
* Amazon CloudWatch Logs for Fluent Bit 1.9.1
* Amazon Kinesis Streams for Fluent Bit 1.10.1
* Amazon Kinesis Firehose for Fluent Bit 1.7.1

*This release is a **CVE patch release for [2.28.4](https://github.com/aws/aws-for-fluent-bit/releases/tag/v2.28.4)**. It contains the same contents but re-built to uptake the most recent Amazon Linux packages with patches.*


### 2.31.7
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.2
* Amazon Kinesis Streams for Fluent Bit 1.10.1
* Amazon Kinesis Firehose for Fluent Bit 1.7.1

Compared to `2.23.6` this release adds:
* Bug - Fixed S3 Key Tag Corruption with `preserve_data_ordering` option [aws-for-fluent-bit:541](https://github.com/aws/aws-for-fluent-bit/issues/541) [fluent-bit:6933](https://github.com/fluent/fluent-bit/issues/6933)

This release includes the same fixes and features that we are working on getting accepted upstream as [AWS for Fluent Bit 2.31.6](https://github.com/aws/aws-for-fluent-bit/releases/tag/v2.31.6).


### 2.31.6
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.2
* Amazon Kinesis Streams for Fluent Bit 1.10.1
* Amazon Kinesis Firehose for Fluent Bit 1.7.1

Compared to `2.23.5` this release adds:
* Bug - Fixed Log Loss can occur when log group creation or retention policy API calls fail [cloudwatch:314](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/314)

This release includes the same fixes and features that we are working on getting accepted upstream as [AWS for Fluent Bit 2.31.5](https://github.com/aws/aws-for-fluent-bit/releases/tag/v2.31.5).


### 2.31.5
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.1
* Amazon Kinesis Streams for Fluent Bit 1.10.1
* Amazon Kinesis Firehose for Fluent Bit 1.7.1

Compared to `2.23.4` this release adds:
* Feature - In the init image, extract Availability Zone from ECS Task Metadata and inject into Fluent Bit container as `AWS_AVAILABILITY_ZONE` environment variable [aws-for-fluent-bit:539](https://github.com/aws/aws-for-fluent-bit/pull/539)

Compared to `2.31.4`, this release removes the following fixes that may introduce instabilities to the S3 plugin:
* Enhancement - Transition S3 to fully synchronous file uploads to improve plugin stability [fluent-bit:6573](https://github.com/fluent/fluent-bit/pull/6573)

Same as `2.31.4`, this release removes the following fixes that may introduce instabilities to the S3 plugin:
* Bug - Support Retry_Limit option in S3 plugin to set retries [fluent-bit:6475](https://github.com/fluent/fluent-bit/pull/6475)
* Bug - Format S3 filename with timestamp from the first log in uploaded file, rather than the time the first log was buffered by the s3 output [aws-for-fluent-bit:459](https://github.com/aws/aws-for-fluent-bit/issues/459)

Same as `2.31.4`, this release includes the following fixes and features that we are working on getting accepted upstream:
* Bug - Resolve cloudwatch_logs duplicate tag match SIGSEGV issue introduced in 2.29.0 [aws-for-fluent-bit:542](https://github.com/aws/aws-for-fluent-bit/issues/542)
* Feature - Add `kinesis_firehose` and `kinesis_streams` support for `time_key_format` milliseconds with `%3N` option, and nanoseconds `9N` and `%L` options [fluent-bit:2831](https://github.com/fluent/fluent-bit/issues/2831)
* Feature - Support OpenSearch Serverless data ingestion via OpenSearch plugin [fluent-bit:6448](https://github.com/fluent/fluent-bit/pull/6448)
* Bug - Mitigate Datadog output plugin issue by reverting recent PR [aws-for-fluent-bit:491](https://github.com/aws/aws-for-fluent-bit/issues/491)
* Bug - Resolve S3 logic to display `log_key` missing warning message if the configured `log_key` field is missing from log payload [fluent-bit:6557](https://github.com/fluent/fluent-bit/pull/6557)
* Bug - ECS Metadata filter gracefuly handle task metadata query errors and cache metadata processing state to improve performance [aws-for-fluent-bit:505](https://github.com/aws/aws-for-fluent-bit/issues/505)
* Bug - Resolve a rare Datadog segfault that occurs when remapping tags [aws-for-fluent-bit:491](https://github.com/aws/aws-for-fluent-bit/issues/491)
* Bug - Resolve `net.keepalive` SIGSEGV issue and priority event loop corruption bug [aws-for-fluent-bit:542](https://github.com/aws/aws-for-fluent-bit/issues/542)

### 2.31.4
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.1
* Amazon Kinesis Streams for Fluent Bit 1.10.1
* Amazon Kinesis Firehose for Fluent Bit 1.7.1

Compared to `2.31.3`, this release removes the following fixes that may introduce instabilities to the S3 plugin:
* Bug - Support Retry_Limit option in S3 plugin to set retries [fluent-bit:6475](https://github.com/fluent/fluent-bit/pull/6475)
* Bug - Format S3 filename with timestamp from the first log in uploaded file, rather than the time the first log was buffered by the s3 output [aws-for-fluent-bit:459](https://github.com/aws/aws-for-fluent-bit/issues/459)

Same as `2.31.3`, this release includes the following fixes and features that we are working on getting accepted upstream:
* Bug - Resolve cloudwatch_logs duplicate tag match SIGSEGV issue introduced in 2.29.0 [aws-for-fluent-bit:542](https://github.com/aws/aws-for-fluent-bit/issues/542)
* Feature - Add `kinesis_firehose` and `kinesis_streams` support for `time_key_format` milliseconds with `%3N` option, and nanoseconds `9N` and `%L` options [fluent-bit:2831](https://github.com/fluent/fluent-bit/issues/2831)
* Feature - Support OpenSearch Serverless data ingestion via OpenSearch plugin [fluent-bit:6448](https://github.com/fluent/fluent-bit/pull/6448)
* Enhancement - Transition S3 to fully synchronous file uploads to improve plugin stability [fluent-bit:6573](https://github.com/fluent/fluent-bit/pull/6573)
* Bug - Mitigate Datadog output plugin issue by reverting recent PR [aws-for-fluent-bit:491](https://github.com/aws/aws-for-fluent-bit/issues/491)
* Bug - Resolve S3 logic to display `log_key` missing warning message if the configured `log_key` field is missing from log payload [fluent-bit:6557](https://github.com/fluent/fluent-bit/pull/6557)
* Bug - ECS Metadata filter gracefuly handle task metadata query errors and cache metadata processing state to improve performance [aws-for-fluent-bit:505](https://github.com/aws/aws-for-fluent-bit/issues/505)
* Bug - Resolve a rare Datadog segfault that occurs when remapping tags [aws-for-fluent-bit:491](https://github.com/aws/aws-for-fluent-bit/issues/491)
* Bug - Resolve `net.keepalive` SIGSEGV issue and priority event loop corruption bug [aws-for-fluent-bit:542](https://github.com/aws/aws-for-fluent-bit/issues/542)

### 2.31.3
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.1
* Amazon Kinesis Streams for Fluent Bit 1.10.1
* Amazon Kinesis Firehose for Fluent Bit 1.7.1

Compared to `2.31.2`, this release adds the following fix that we are working on getting accepted upstream:
* Bug - Resolve `net.keepalive` SIGSEGV issue and priority event loop corruption bug [aws-for-fluent-bit:542](https://github.com/aws/aws-for-fluent-bit/issues/542)

Same as `2.31.2`, this release includes the following fixes and features that we are working on getting accepted upstream:
* Bug - Resolve cloudwatch_logs duplicate tag match SIGSEGV issue introduced in 2.29.0 [aws-for-fluent-bit:542](https://github.com/aws/aws-for-fluent-bit/issues/542)
* Feature - Add `kinesis_firehose` and `kinesis_streams` support for `time_key_format` milliseconds with `%3N` option, and nanoseconds `9N` and `%L` options [fluent-bit:2831](https://github.com/fluent/fluent-bit/issues/2831)
* Feature - Support OpenSearch Serverless data ingestion via OpenSearch plugin [fluent-bit:6448](https://github.com/fluent/fluent-bit/pull/6448)
* Enhancement - Transition S3 to fully synchronous file uploads to improve plugin stability [fluent-bit:6573](https://github.com/fluent/fluent-bit/pull/6573)
* Bug - Mitigate Datadog output plugin issue by reverting recent PR [aws-for-fluent-bit:491](https://github.com/aws/aws-for-fluent-bit/issues/491)
* Bug - Format S3 filename with timestamp from the first log in uploaded file, rather than the time the first log was buffered by the s3 output [aws-for-fluent-bit:459](https://github.com/aws/aws-for-fluent-bit/issues/459)
* Bug - Resolve S3 logic to display `log_key` missing warning message if the configured `log_key` field is missing from log payload [fluent-bit:6557](https://github.com/fluent/fluent-bit/pull/6557)
* Bug - ECS Metadata filter gracefuly handle task metadata query errors and cache metadata processing state to improve performance [aws-for-fluent-bit:505](https://github.com/aws/aws-for-fluent-bit/issues/505)
* Bug - Support Retry_Limit option in S3 plugin to set retries [fluent-bit:6475](https://github.com/fluent/fluent-bit/pull/6475)
* Bug - Resolve a rare Datadog segfault that occurs when remapping tags [aws-for-fluent-bit:491](https://github.com/aws/aws-for-fluent-bit/issues/491)

### 2.31.2
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.1
* Amazon Kinesis Streams for Fluent Bit 1.10.1
* Amazon Kinesis Firehose for Fluent Bit 1.7.1

Compared to `2.31.1`, this release adds the following feature that we are working on getting accepted upstream:
* Bug - Resolve cloudwatch_logs duplicate tag match SIGSEGV issue introduced in 2.29.0 [aws-for-fluent-bit:542](https://github.com/aws/aws-for-fluent-bit/issues/542)

Same as `2.31.1`, this release includes the following fixes and features that we are working on getting accepted upstream:
* Feature - Add `kinesis_firehose` and `kinesis_streams` support for `time_key_format` milliseconds with `%3N` option, and nanoseconds `9N` and `%L` options [fluent-bit:2831](https://github.com/fluent/fluent-bit/issues/2831)
* Feature - Support OpenSearch Serverless data ingestion via OpenSearch plugin [fluent-bit:6448](https://github.com/fluent/fluent-bit/pull/6448)
* Enhancement - Transition S3 to fully synchronous file uploads to improve plugin stability [fluent-bit:6573](https://github.com/fluent/fluent-bit/pull/6573)
* Bug - Mitigate Datadog output plugin issue by reverting recent PR [aws-for-fluent-bit:491](https://github.com/aws/aws-for-fluent-bit/issues/491)
* Bug - Format S3 filename with timestamp from the first log in uploaded file, rather than the time the first log was buffered by the s3 output [aws-for-fluent-bit:459](https://github.com/aws/aws-for-fluent-bit/issues/459)
* Bug - Resolve S3 logic to display `log_key` missing warning message if the configured `log_key` field is missing from log payload [fluent-bit:6557](https://github.com/fluent/fluent-bit/pull/6557)
* Bug - ECS Metadata filter gracefuly handle task metadata query errors and cache metadata processing state to improve performance [aws-for-fluent-bit:505](https://github.com/aws/aws-for-fluent-bit/issues/505)
* Bug - Support Retry_Limit option in S3 plugin to set retries [fluent-bit:6475](https://github.com/fluent/fluent-bit/pull/6475)
* Bug - Resolve a rare Datadog segfault that occurs when remapping tags [aws-for-fluent-bit:491](https://github.com/aws/aws-for-fluent-bit/issues/491)

### 2.31.1
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.1
* Amazon Kinesis Streams for Fluent Bit 1.10.1
* Amazon Kinesis Firehose for Fluent Bit 1.7.1

Compared to `2.31.0`, this release adds the following feature that we are working on getting accepted upstream:
* Bug - Support Retry_Limit option in S3 plugin to set retries [fluent-bit:6475](https://github.com/fluent/fluent-bit/pull/6475)
* Bug - Resolve a rare Datadog segfault that occurs when remapping tags [aws-for-fluent-bit:491](https://github.com/aws/aws-for-fluent-bit/issues/491)

Same as `2.31.0`, this release includes the following fixes and features that we are working on getting accepted upstream:
* Feature - Add `kinesis_firehose` and `kinesis_streams` support for `time_key_format` milliseconds with `%3N` option, and nanoseconds `9N` and `%L` options [fluent-bit:2831](https://github.com/fluent/fluent-bit/issues/2831)
* Feature - Support OpenSearch Serverless data ingestion via OpenSearch plugin [fluent-bit:6448](https://github.com/fluent/fluent-bit/pull/6448)
* Enhancement - Transition S3 to fully synchronous file uploads to improve plugin stability [fluent-bit:6573](https://github.com/fluent/fluent-bit/pull/6573)
* Bug - Mitigate Datadog output plugin issue by reverting recent PR [aws-for-fluent-bit:491](https://github.com/aws/aws-for-fluent-bit/issues/491)
* Bug - Format S3 filename with timestamp from the first log in uploaded file, rather than the time the first log was buffered by the s3 output [aws-for-fluent-bit:459](https://github.com/aws/aws-for-fluent-bit/issues/459)
* Bug - Resolve S3 logic to display `log_key` missing warning message if the configured `log_key` field is missing from log payload [fluent-bit:6557](https://github.com/fluent/fluent-bit/pull/6557)
* Bug - ECS Metadata filter gracefuly handle task metadata query errors and cache metadata processing state to improve performance [aws-for-fluent-bit:505](https://github.com/aws/aws-for-fluent-bit/issues/505)


### 2.31.0
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.1
* Amazon Kinesis Streams for Fluent Bit 1.10.1
* Amazon Kinesis Firehose for Fluent Bit 1.7.1

Compared to `2.30.0`, this release adds the following feature that we are working on getting accepted upstream:
* Feature - Add `kinesis_firehose` and `kinesis_streams` support for `time_key_format` milliseconds with `%3N` option, and nanoseconds `9N` and `%L` options [fluent-bit:2831](https://github.com/fluent/fluent-bit/issues/2831)
* Bug - Format S3 filename with timestamp from the first log in uploaded file, rather than the time the first log was buffered by the s3 output [aws-for-fluent-bit:459](https://github.com/aws/aws-for-fluent-bit/issues/459)
* Enhancement - Transition S3 to fully synchronous file uploads to improve plugin stability [fluent-bit:6573](https://github.com/fluent/fluent-bit/pull/6573)
* Bug - Resolve S3 logic to display `log_key` missing warning message if the configured `log_key` field is missing from log payload [fluent-bit:6557](https://github.com/fluent/fluent-bit/pull/6557)
* Bug - ECS Metadata filter gracefuly handle task metadata query errors and cache metadata processing state to improve performance [aws-for-fluent-bit:505](https://github.com/aws/aws-for-fluent-bit/issues/505)

Same as `2.30.0`, this release includes the following fixes and features that we are working on getting accepted upstream:
* Feature - Support OpenSearch Serverless data ingestion via OpenSearch plugin [fluent-bit:6448](https://github.com/fluent/fluent-bit/pull/6448)
* Bug - Mitigate Datadog output plugin issue by reverting recent PR [aws-for-fluent-bit:491](https://github.com/aws/aws-for-fluent-bit/issues/491)

### 2.30.0
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.1
* Amazon Kinesis Streams for Fluent Bit 1.10.1
* Amazon Kinesis Firehose for Fluent Bit 1.7.1

Compared to `2.29.1`, this release adds the following feature that we are working on getting accepted upstream:
* Feature - Support OpenSearch Serverless data ingestion via OpenSearch plugin [fluent-bit:6448](https://github.com/fluent/fluent-bit/pull/6448)

Same as `2.29.1`, this release includes the following fix that we are working on getting accepted upstream:
* Bug - Mitigate Datadog output plugin issue by reverting recent PR [aws-for-fluent-bit:491](https://github.com/aws/aws-for-fluent-bit/issues/491)

### 2.29.1
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.1
* Amazon Kinesis Streams for Fluent Bit 1.10.1
* Amazon Kinesis Firehose for Fluent Bit 1.7.1

Compared to `2.29.0`, this release includes the following fix that we are working on getting accepted upstream:
* Bug - Mitigate Datadog output plugin issue by reverting recent PR [aws-for-fluent-bit:491](https://github.com/aws/aws-for-fluent-bit/issues/491)

### 2.29.0
This release includes:
* Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)
* Amazon CloudWatch Logs for Fluent Bit 1.9.1
* Amazon Kinesis Streams for Fluent Bit 1.10.1
* Amazon Kinesis Firehose for Fluent Bit 1.7.1

Compared to `2.28.4` this release adds:
* Feature - Add `store_dir_limit_size` option [fluentbit-docs:971](https://github.com/fluent/fluent-bit-docs/pull/971)
* Feature - New filter for AWS ECS Metadata [fluentbit:5898](https://github.com/fluent/fluent-bit/pull/5898)
* Enhancement - Different user agent on windows vs linux [fluentbit:6325](https://github.com/fluent/fluent-bit/pull/6325)
* Bug - Resolve Fluent Bit networking hangs affecting CloudWatch plugin by migrating to async networking + sync core scheduler [fluentbit:6339](https://github.com/fluent/fluent-bit/pull/6339)

### 2.28.4
This release includes:
* Fluent Bit [1.9.9](https://fluentbit.io/announcements/v1.9.9/)
* Amazon CloudWatch Logs for Fluent Bit 1.9.1
* Amazon Kinesis Streams for Fluent Bit 1.10.1
* Amazon Kinesis Firehose for Fluent Bit 1.7.1

Important Note:
* Two security vulnerabilities were found in amazonlinux which we use as our base image- [ALAS-40674](https://alas.aws.amazon.com/cve/html/CVE-2022-40674.html) and [ALAS-32207](https://alas.aws.amazon.com/cve/html/CVE-2022-32207.html). This new image will be based on an updated version of amazonlinux that resolves this CVE.
* This is the first release for aws-for-fluent-bit Windows. Therefore, at launch this has been marked as the stable version. However, with future versions, the stable tag would be older than latest and would have been vetted for stability by the customers.

Compared to `2.28.3` this release adds the following feature that we are working on getting accepted upstream:
* enhancement - Separate AWS User Agents for windows and linux [fluentbit:6325](https://github.com/fluent/fluent-bit/pull/6325)

### 2.28.3
This release includes:
* Fluent Bit [1.9.9](https://fluentbit.io/announcements/v1.9.9/)
* Amazon CloudWatch Logs for Fluent Bit 1.9.0
* Amazon Kinesis Streams for Fluent Bit 1.10.0
* Amazon Kinesis Firehose for Fluent Bit 1.7.0

Important Note:
* A security vulnerability was found in [golang](https://alas.aws.amazon.com/ALAS-2022-1635.html) which we use to build our go plugins. This new image builds the go plugins with latest golang and resolves the CVE.

### 2.28.2
This release includes:
* Fluent Bit [1.9.9](https://fluentbit.io/announcements/v1.9.9/)
* Amazon CloudWatch Logs for Fluent Bit 1.9.0
* Amazon Kinesis Streams for Fluent Bit 1.10.0
* Amazon Kinesis Firehose for Fluent Bit 1.7.0

Compared to `2.28.1` this release adds:
* Bug - Stop trace_error from truncating the OpenSearch API call response [fluentbit:5788](https://github.com/fluent/fluent-bit/pull/5788)

### 2.28.1
This release includes:
* Fluent Bit [1.9.8](https://fluentbit.io/announcements/v1.9.8/)
* Amazon CloudWatch Logs for Fluent Bit 1.9.0
* Amazon Kinesis Streams for Fluent Bit 1.10.0
* Amazon Kinesis Firehose for Fluent Bit 1.7.0

Compared to `2.28.0` this release adds the following feature that we are working on getting accepted upstream:
* Bug - Resolve long tag segfault issue. Without this patch, Fluent Bit may segfault if it encounters tags over 256 characters in length. [fluentbit:5753](https://github.com/fluent/fluent-bit/issues/5753)

### 2.28.0
This release includes:
* Fluent Bit [1.9.7](https://fluentbit.io/announcements/v1.9.7/)
* Amazon CloudWatch Logs for Fluent Bit 1.9.0
* Amazon Kinesis Streams for Fluent Bit 1.10.0
* Amazon Kinesis Firehose for Fluent Bit 1.7.0

Compared to `2.27.0` this release adds:
* Feature - Add gzip compression support for multipart uploads in [S3 Output plugin](https://docs.fluentbit.io/manual/pipeline/outputs/s3/)
* Bug - S3 output key formatting inconsistent rendering of `$TAG[n]` [aws-for-fluent-bit:376](https://github.com/aws/aws-for-fluent-bit/issues/376)
* Bug - fix concurrency issue in S3 key formatting
* Bug - `cloudwatch_logs` plugin fix skip counting empty events

### 2.27.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.9.6](https://fluentbit.io/announcements/v1.9.6/)
* Amazon CloudWatch Logs for Fluent Bit 1.9.0
* Amazon Kinesis Streams for Fluent Bit 1.10.0
* Amazon Kinesis Firehose for Fluent Bit 1.7.0

Compared to `2.26.0` this release adds:
* Feature - Add support for record accessor on `cloudwatch_logs` plugin [fluentbit:3246](https://github.com/fluent/fluent-bit/issues/3246)
* Enhancement - Update S3 PutObject size to 1GB [s3:5688](https://github.com/fluent/fluent-bit/pull/5688)
* Bug - Clear last recently used parser to match next parser for multiline filter [fluentbit:5524](https://github.com/fluent/fluent-bit/issues/5524)

### 2.26.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.9.4](https://fluentbit.io/announcements/v1.9.4/)
* Amazon CloudWatch Logs for Fluent Bit 1.8.0
* Amazon Kinesis Streams for Fluent Bit 1.9.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Compared to `2.25.1` this release adds:
* Feature - Add `auto_create_stream ` option [cloudwatch:257](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/pull/257)
* Feature - Enable Apache Arrow support in S3 at compile time [s3:3184](https://github.com/fluent/fluent-bit/pull/3184)
* Enhancement - Add debug logs to check batch sizes [fluentbit:5428](https://github.com/fluent/fluent-bit/pull/5428)
* Enhancement - Set 1 worker as default for `cloudwatch_logs` plugin [fluentbit:5417](https://github.com/fluent/fluent-bit/pull/5417)
* Bug - Allow recovery from a stream being deleted and created by a user [cloudwatch:257](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/pull/257)

Same as `2.25.1`, this release includes the following enhancement for AWS customers that has been accepted by upstream:
* Enhancement - Add `kube_token_ttl` option to kubernetes filter to support refreshing the service account token used to talk to the API server. Prior to this change Fluent Bit would only read the token on startup. [fluentbit:5332](https://github.com/fluent/fluent-bit/issues/5332)

### 2.25.1
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.9.3](https://fluentbit.io/announcements/v1.9.3/)
* Amazon CloudWatch Logs for Fluent Bit 1.7.0
* Amazon Kinesis Streams for Fluent Bit 1.9.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Compared to `2.25.0` this release adds:
* Bug - Fix new `kube_token_ttl` option in kubernetes filter to correctly parse TTL as a time value [aws-for-fluent-bit:353](https://github.com/aws/aws-for-fluent-bit/issues/353)

### 2.25.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.9.3](https://fluentbit.io/announcements/v1.9.3/)
* Amazon CloudWatch Logs for Fluent Bit 1.7.0
* Amazon Kinesis Streams for Fluent Bit 1.9.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Compared to `2.24.0` this release adds the following feature that we are working on getting accepted upstream:
* Enhancement - Add `kube_token_ttl` option to kubernetes filter to support refreshing the service account token used to talk to the API server. Prior to this change Fluent Bit would only read the token on startup. [fluentbit:5332](https://github.com/fluent/fluent-bit/issues/5332)

### 2.24.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.9.3](https://fluentbit.io/announcements/v1.9.3/)
* Amazon CloudWatch Logs for Fluent Bit 1.7.0
* Amazon Kinesis Streams for Fluent Bit 1.9.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Compared to `2.23.4` this release adds:
* Bug - Resolve IMDSv1 fallback error introduced in 2.21.0 [aws-for-fluent-bit:259](https://github.com/aws/aws-for-fluent-bit/issues/259)
* Bug - Cloudwatch Fix integer overflow on 32 bit systems when converting tv_sec to millis [fluentbit:3640](https://github.com/fluent/fluent-bit/issues/3640)
* Enhancement - Only create Cloudwatch Logs log group if it does not already exist to prevent throttling [fluentbit:4826](https://github.com/fluent/fluent-bit/pull/4826)
* Enhancement - Implement docker log driver partial message support for multiline buffered mode [fluentbit:4671](https://github.com/fluent/fluent-bit/pull/4671)
* Enhancement - Gracefully handle Cloudwatch Logs DataAlreadyAcceptedException [fluentbit:4948](https://github.com/fluent/fluent-bit/pull/4948)
* Feature - Add sigv4 authentication options to HTTP output plugin [fluentbit:5165](https://github.com/fluent/fluent-bit/pull/5165)
* Feature - Add Firehose compression configuration options [fluentbit:4371](https://github.com/fluent/fluent-bit/pull/4371)
* New Plugin - [`opensearch` plugin in Fluent Bit core](https://docs.fluentbit.io/manual/pipeline/outputs/opensearch)

### 2.23.4
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.15](https://fluentbit.io/announcements/v1.8.15/)
* Amazon CloudWatch Logs for Fluent Bit 1.7.0
* Amazon Kinesis Streams for Fluent Bit 1.9.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Compared to `2.23.3` this release adds:
* Go version upgrade to 1.17.9

Same as `2.23.2`, this release includes the following fix for AWS customers that we are working on getting accepted upstream:
* Bug - Resolve IMDSv1 fallback error introduced in 2.21.0 [aws-for-fluent-bit:259](https://github.com/aws/aws-for-fluent-bit/issues/259)

Important Note:
* A security vulnerability was found in [amazonlinux](https://alas.aws.amazon.com/AL2/ALAS-2022-1772.html) which we use as our base image. This new image will be based on an updated version of amazonlinux that resolves this CVE.

### 2.23.3
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.15](https://fluentbit.io/announcements/v1.8.15/)
* Amazon CloudWatch Logs for Fluent Bit 1.7.0
* Amazon Kinesis Streams for Fluent Bit 1.9.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Same as `2.23.2`, this release includes the following fix for AWS customers that we are working on getting accepted upstream:
* Bug - Resolve IMDSv1 fallback error introduced in 2.21.0 [aws-for-fluent-bit:259](https://github.com/aws/aws-for-fluent-bit/issues/259)

New Tool:
* [firelens-datajet](https://github.com/aws/firelens-datajet) is a holistic log/metric routing software test tool made to flexibly send test data to Fluent Bit in a repeatable, reliable, and portable manner. Create test configuration JSONs that modularly connect test data generators to data senders, customize data generation rate, send data in parallel over various ingestion routes, and mock log router destinations.

### 2.23.2
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.14](https://fluentbit.io/announcements/v1.8.14/)
* Amazon CloudWatch Logs for Fluent Bit 1.7.0
* Amazon Kinesis Streams for Fluent Bit 1.9.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Compared to `2.23.1` this release adds:
* Enhancement - Mitigate throttling issue on log group in cloudwatch_logs plugin [fluentbit:4826](https://github.com/fluent/fluent-bit/pull/4826)

Same as `2.23.1`, this release includes the following fix for AWS customers that we are working on getting accepted upstream:
* Bug - Resolve IMDSv1 fallback error introduced in 2.21.0 [aws-for-fluent-bit:259](https://github.com/aws/aws-for-fluent-bit/issues/259)

### 2.23.1
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.13](https://fluentbit.io/announcements/v1.8.13/)
* Amazon CloudWatch Logs for Fluent Bit 1.7.0
* Amazon Kinesis Streams for Fluent Bit 1.9.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Same as `2.23.0`, this release includes the following fix for AWS customers that we are working on getting accepted upstream:
* Bug - Resolve IMDSv1 fallback error introduced in 2.21.0 [aws-for-fluent-bit:259](https://github.com/aws/aws-for-fluent-bit/issues/259)

Important Note:
* Two security vulnerability were found in amazonlinux which we use as base image to our `aws-for-fluent-bit` image- [ALAS-2022-1764](https://alas.aws.amazon.com/AL2/ALAS-2022-1764.html) and [ALAS-2022-1766](https://alas.aws.amazon.com/AL2/ALAS-2022-1766.html). This new image will be based on an updated version of amazonlinux that resolves these CVEs.

### 2.23.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.13](https://fluentbit.io/announcements/v1.8.13/)
* Amazon CloudWatch Logs for Fluent Bit 1.7.0
* Amazon Kinesis Streams for Fluent Bit 1.9.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Compared to `2.22.0` this release adds:
* Feature - Add timeout config for AWS SDK Go HTTP calls [kinesis:178](https://github.com/aws/amazon-kinesis-streams-for-fluent-bit/issues/178)
* Enhancement - Migrate AWS plugins to performant 2.25.0-mbedtls base64 implementation [fluentbit:4422](https://github.com/fluent/fluent-bit/pull/4422)
* Bug - Fix message loss issue using concurrency feature with 0 retries [kinesis:179](https://github.com/aws/amazon-kinesis-streams-for-fluent-bit/pull/179)

Compared to `2.22.0` this release deletes the following fix which has been covered in new enhancement:
* Bug - Downgrade `mbedtls` to 2.24.0 to fix the performance regression issue in `mbedtls` 2.26.0 [fluentbit:4110](https://github.com/fluent/fluent-bit/issues/4110)

Same as `2.22.0`, this release includes the following fix for AWS customers that we are working on getting accepted upstream:
* Bug - Resolve IMDSv1 fallback error introduced in 2.21.0 [aws-for-fluent-bit:259](https://github.com/aws/aws-for-fluent-bit/issues/259)

### 2.22.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.12](https://fluentbit.io/announcements/v1.8.12/)
* Amazon CloudWatch Logs for Fluent Bit 1.7.0
* Amazon Kinesis Streams for Fluent Bit 1.8.1
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Compared to `2.21.6` this release adds:
* Feature - The multiline filter now fully supports key ECS multiline log use cases using regular expressions [aws-for-fluent-bit:100](https://github.com/aws/aws-for-fluent-bit/issues/100)
* Feature - Add support for external_id in AWS output plugins [aws-for-fluent-bit:171](https://github.com/aws/aws-for-fluent-bit/issues/171)
* Bug - Fix truncation issue after compression [kinesis:183](https://github.com/aws/amazon-kinesis-streams-for-fluent-bit/issues/183)

Same as `2.21.6`, this release includes the following fix for AWS customers that has been accepted by upstream:
* Bug - Fix return value from `tls_net_read` [fluentbit:4098](https://github.com/fluent/fluent-bit/issues/4098)

Same as `2.21.6`, this release includes the following fixes for AWS customers that we are working on getting accepted upstream:
* Bug - Downgrade `mbedtls` to 2.24.0 to fix the performance regression issue in `mbedtls` 2.26.0 [fluentbit:4110](https://github.com/fluent/fluent-bit/issues/4110)
* Bug - Resolve IMDSv1 fallback error introduced in 2.21.0 [aws-for-fluent-bit:259](https://github.com/aws/aws-for-fluent-bit/issues/259)

### 2.21.6
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.11](https://fluentbit.io/announcements/v1.8.11/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.4
* Amazon Kinesis Streams for Fluent Bit 1.8.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Compared to `2.21.5` this release adds:
* Go version upgrade to 1.17.6

Same as `2.21.5`, this release includes the following fixes for AWS customers that we are working on getting accepted upstream:
* Bug - Fix return value from `tls_net_read` [fluentbit:4098](https://github.com/fluent/fluent-bit/issues/4098)
* Bug - Downgrade `mbedtls` to 2.24.0 to fix the performance regression issue in `mbedtls` 2.26.0 [fluentbit:4110](https://github.com/fluent/fluent-bit/issues/4110)
* Bug - Resolve IMDSv1 fallback error introduced in 2.21.0 [aws-for-fluent-bit:259](https://github.com/aws/aws-for-fluent-bit/issues/259)

### 2.21.5
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.11](https://fluentbit.io/announcements/v1.8.11/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.4
* Amazon Kinesis Streams for Fluent Bit 1.8.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Same as `2.21.4`, this release includes the following fixes for AWS customers that we are working on getting accepted upstream:
* Bug - Fix return value from `tls_net_read` [fluentbit:4098](https://github.com/fluent/fluent-bit/issues/4098)
* Bug - Downgrade `mbedtls` to 2.24.0 to fix the performance regression issue in `mbedtls` 2.26.0 [fluentbit:4110](https://github.com/fluent/fluent-bit/issues/4110)
* Bug - Resolve IMDSv1 fallback error introduced in 2.21.0 [aws-for-fluent-bit:259](https://github.com/aws/aws-for-fluent-bit/issues/259)

### 2.21.4
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.10](https://fluentbit.io/announcements/v1.8.10/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.4
* Amazon Kinesis Streams for Fluent Bit 1.8.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Compared to `2.21.3` this release adds:
* Bug - Fix handling of TCP connections on SIGTERM [fluentbit:2610](https://github.com/fluent/fluent-bit/pull/2610)
* Bug - Auto retry invalid cloudwatch requests to resolve sequence token errors [fluentbit:4189](https://github.com/fluent/fluent-bit/pull/4189)

Same as `2.21.3`, this release includes the following fixes for AWS customers that we are working on getting accepted upstream:
* Bug - Fix return value from `tls_net_read` [fluentbit:4098](https://github.com/fluent/fluent-bit/issues/4098)
* Bug - Downgrade `mbedtls` to 2.24.0 to fix the performance regression issue in `mbedtls` 2.26.0 [fluentbit:4110](https://github.com/fluent/fluent-bit/issues/4110)
* Bug - Resolve IMDSv1 fallback error introduced in 2.21.0 [aws-for-fluent-bit:259](https://github.com/aws/aws-for-fluent-bit/issues/259)

### 2.21.3
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.9](https://fluentbit.io/announcements/v1.8.9/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.4
* Amazon Kinesis Streams for Fluent Bit 1.8.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Same as `2.21.2`, this release includes the following fixes for AWS customers that we are working on getting accepted upstream:
* Bug - Fix return value from `tls_net_read` [fluentbit:4098](https://github.com/fluent/fluent-bit/issues/4098)
* Bug - Downgrade `mbedtls` to 2.24.0 to fix the performance regression issue in `mbedtls` 2.26.0 [fluentbit:4110](https://github.com/fluent/fluent-bit/issues/4110)
* Bug - Resolve IMDSv1 fallback error introduced in 2.21.0 [aws-for-fluent-bit:259](https://github.com/aws/aws-for-fluent-bit/issues/259)

Important Note:
* A security vulnerability was found in [amazonlinux](https://access.redhat.com/security/cve/CVE-2021-43527) which we use as base image to our `aws-for-fluent-bit` image. This new image will be based on an updated version of amazonlinux that resolves this CVE.

### 2.21.2
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.9](https://fluentbit.io/announcements/v1.8.9/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.4
* Amazon Kinesis Streams for Fluent Bit 1.8.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Compared to `2.21.1` this release adds:
* Bug - Remove corrupted unicode fragments on truncation [aws-for-fluent-bit:252](https://github.com/aws/aws-for-fluent-bit/issues/252)

Compared to `2.21.1` this release includes the following fixes for AWS customers that we are working on getting accepted upstream:
* Bug - Resolve IMDSv1 fallback error introduced in 2.21.0 [aws-for-fluent-bit:259](https://github.com/aws/aws-for-fluent-bit/issues/259)

Same as `2.21.1`, this release includes the following fixes for AWS customers that we are working on getting accepted upstream:
* Bug - Fix return value from `tls_net_read` [fluentbit:4098](https://github.com/fluent/fluent-bit/issues/4098)
* Bug - Downgrade `mbedtls` to 2.24.0 to fix the performance regression issue in `mbedtls` 2.26.0 [fluentbit:4110](https://github.com/fluent/fluent-bit/issues/4110)

### 2.21.1
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.9](https://fluentbit.io/announcements/v1.8.9/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.3
* Amazon Kinesis Streams for Fluent Bit 1.8.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Compared to `2.21.0` this release adds:
* Bug - Avoid double free for multiline msgpack buffer [fluentbit:4243](https://github.com/fluent/fluent-bit/pull/4243)
* Bug - On Multiline handling, use file inode as stream_id [fluentbit:3886](https://github.com/fluent/fluent-bit/issues/3886)

Same as `2.21.0`, this release includes the following fixes for AWS customers that we are working on getting accepted upstream:
* Bug - Fix return value from `tls_net_read` [fluentbit:4098](https://github.com/fluent/fluent-bit/issues/4098)
* Bug - Downgrade `mbedtls` to 2.24.0 to fix the performance regression issue in `mbedtls` 2.26.0 [fluentbit:4110](https://github.com/fluent/fluent-bit/issues/4110)

### 2.21.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.8](https://fluentbit.io/announcements/v1.8.8/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.3
* Amazon Kinesis Streams for Fluent Bit 1.8.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Compared to `2.20.0` this release adds:
* Feature/Warning - This release introduces IMDSv2 support. Instances that rely on IMDS for security credentials must set EC2's instance-metadata-option `http-put-response-hop-limit` to `2` otherwise Fluent Bit will hang [aws-for-fluent-bit:259](https://github.com/aws/aws-for-fluent-bit/pull/259)
* Bug - Fix memory leak in S3 output [fluentbit:4038](https://github.com/fluent/fluent-bit/issues/4038)
* Bug - Fix return value from `tls_net_read` [fluentbit:4098](https://github.com/fluent/fluent-bit/issues/4098)
* Bug - Downgrade `mbedtls` to 2.24.0 to fix the performance regression issue in `mbedtls` 2.26.0 [fluentbit:4110](https://github.com/fluent/fluent-bit/issues/4110)

### 2.20.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.7](https://fluentbit.io/announcements/v1.8.7/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.3
* Amazon Kinesis Streams for Fluent Bit 1.8.0
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Compared to `2.19.2` this release adds:
* Feature - Add support for gzip compression of records [kinesis:162](https://github.com/aws/amazon-kinesis-streams-for-fluent-bit/pull/162)
* Enhancement - Build `aws-for-fluent-bit` image with release mode rather than debug mode [aws-for-fluent-bit:249](https://github.com/aws/aws-for-fluent-bit/pull/249)
* Bug - Fix return value from `tls_net_read` [fluentbit:4098](https://github.com/fluent/fluent-bit/issues/4098)
* Bug - Downgrade `mbedtls` to 2.24.0 to fix the performance regression issue in `mbedtls` 2.26.0 [fluentbit:4110](https://github.com/fluent/fluent-bit/issues/4110)

Important Note:
* Besides upgrading Fluent Bit version to 1.8.7, we also include some customized changes with this latest version (2.20.0) of `aws-for-fluent-bit` image. This aims to fix performance and stability issues in Fluent Bit.

### 2.19.2
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.6](https://fluentbit.io/announcements/v1.8.6/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.3
* Amazon Kinesis Streams for Fluent Bit 1.7.3
* Amazon Kinesis Firehose for Fluent Bit 1.6.1

Compared to `2.19.1` this release adds:
* Enhancement - Upgrade Go version to 1.17

### 2.19.1
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.6](https://fluentbit.io/announcements/v1.8.6/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.2
* Amazon Kinesis Streams for Fluent Bit 1.7.2
* Amazon Kinesis Firehose for Fluent Bit 1.6.0

Compared to `2.19.0` this release adds:
* Enhancement - Add validation to stop accepting both of `log_stream_name` and `log_stream_prefix` together [cloudwatch:190](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/pull/190)
* Bug - Fix aggregator size estimation [kinesis:155](https://github.com/aws/amazon-kinesis-streams-for-fluent-bit/pull/155)
* Bug - Fix partition key computation for aggregation [kinesis:158](https://github.com/aws/amazon-kinesis-streams-for-fluent-bit/pull/158)

### 2.19.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.3](https://fluentbit.io/announcements/v1.8.3/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.1
* Amazon Kinesis Streams for Fluent Bit 1.7.1
* Amazon Kinesis Firehose for Fluent Bit 1.6.0

### 2.18.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.2](https://fluentbit.io/announcements/v1.8.2/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.1
* Amazon Kinesis Streams for Fluent Bit 1.7.1
* Amazon Kinesis Firehose for Fluent Bit 1.6.0

Compared to `2.17.0` this release adds:
* Feature - [Multiline Filter](https://docs.fluentbit.io/manual/pipeline/filters/multiline-stacktrace) which helps to concatenate messages that originally belong to one context but were split across multiple records or log lines.

### 2.17.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.8.1](https://fluentbit.io/announcements/v1.8.1/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.1
* Amazon Kinesis Streams for Fluent Bit 1.7.1
* Amazon Kinesis Firehose for Fluent Bit 1.6.0

### 2.16.1
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.7.9](https://fluentbit.io/announcements/v1.7.9/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.1
* Amazon Kinesis Streams for Fluent Bit 1.7.1
* Amazon Kinesis Firehose for Fluent Bit 1.6.0

Important Note:
* We fixed known issues which were found in our previous version v2.16.0. This new image will use the updated version of our dependencies. It is highly recommended to upgrade your existing workload or run new workload with this latest version (2.16.1) of `aws-for-fluent-bit` image.

### 2.16.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.7.9](https://fluentbit.io/announcements/v1.7.9/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.1
* Amazon Kinesis Streams for Fluent Bit 1.7.1
* Amazon Kinesis Firehose for Fluent Bit 1.6.0

### 2.15.1
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.7.8](https://www.fluentbit.io/announcements/v1.7.8/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.1
* Amazon Kinesis Streams for Fluent Bit 1.7.1
* Amazon Kinesis Firehose for Fluent Bit 1.6.0

### 2.15.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.7.6](https://fluentbit.io/announcements/v1.7.6/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.1
* Amazon Kinesis Streams for Fluent Bit 1.7.1
* Amazon Kinesis Firehose for Fluent Bit 1.6.0

Important Note:
* Two different security vulnerabilities were found in [openssl](https://access.redhat.com/security/cve/CVE-2021-3449) and [glibc](https://access.redhat.com/security/cve/CVE-2021-3326) which we use to build our `aws-for-fluent-bit` image. This new image will use the updated version of these dependencies. It is highly recommended to upgrade your existing workload or run new workload with this latest version (2.15.0) of `aws-for-fluent-bit` image.

### 2.14.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.7.4](https://fluentbit.io/announcements/v1.7.4/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.1
* Amazon Kinesis Streams for Fluent Bit 1.7.1
* Amazon Kinesis Firehose for Fluent Bit 1.6.0

### 2.13.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.7.3](https://fluentbit.io/announcements/v1.7.3/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.1
* Amazon Kinesis Streams for Fluent Bit 1.7.1
* Amazon Kinesis Firehose for Fluent Bit 1.6.0

Compared to `2.12.0` this release adds:
* Enhancement - Delete debug messages which make log info useless [cloudwatch:141](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/141)

### 2.12.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.7.2](https://fluentbit.io/announcements/v1.7.2/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.0
* Amazon Kinesis Streams for Fluent Bit 1.7.1
* Amazon Kinesis Firehose for Fluent Bit 1.6.0

Compared to `2.11.0` this release adds:
* Enhancement - Add an option to send multiple log events as a record [firehose:12](https://github.com/aws/amazon-kinesis-firehose-for-fluent-bit/issues/12)

### 2.11.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.6.10](https://fluentbit.io/announcements/v1.6.10/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.0
* Amazon Kinesis Streams for Fluent Bit 1.7.1
* Amazon Kinesis Firehose for Fluent Bit 1.5.1

**This release removes /var/cache/yum to reduce the size of the container image; you can no longer `yum install` packages in this image.**

### 2.10.1
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.6.10](https://fluentbit.io/announcements/v1.6.10/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.0
* Amazon Kinesis Streams for Fluent Bit 1.7.1
* Amazon Kinesis Firehose for Fluent Bit 1.5.1

**This is the first release with images in [Amazon ECR Public Gallery](https://gallery.ecr.aws/aws-observability/aws-for-fluent-bit).**

### 2.10.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.6.8](https://fluentbit.io/announcements/v1.6.8/)
* Amazon CloudWatch Logs for Fluent Bit 1.6.0
* Amazon Kinesis Streams for Fluent Bit 1.7.1
* Amazon Kinesis Firehose for Fluent Bit 1.5.1

Compared to `2.9.0` this release adds:
* Enhancement - Add support for updating the retention policy of existing log groups [cloudwatch:121](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/121)

### 2.9.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.6.3](https://fluentbit.io/announcements/v1.6.3/)
* Amazon CloudWatch Logs for Fluent Bit 1.5.0
* Amazon Kinesis Streams for Fluent Bit 1.7.0
* Amazon Kinesis Firehose for Fluent Bit 1.5.0

**This is the first release with images for both x86 and arm64.**

Compared to `2.8.0` this release adds:
* Feature - Automatically re-create CloudWatch log groups and log streams if they are deleted [cloudwatch:95](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/95)
* Feature - Add default fallback log group and stream names [cloudwatch:99](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/99)
* Feature - Add support for ECS Metadata and UUID via special variables in log stream and group names [cloudwatch:108](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/108)
* Feature - Add new option replace_dots to replace dots in key names in `firehose` and `kinesis` plugins [firehose:46](https://github.com/aws/amazon-kinesis-firehose-for-fluent-bit/issues/46)
* Enhancement - Add support for nested partition_key in log record [kinesis:30](https://github.com/aws/amazon-kinesis-streams-for-fluent-bit/issues/30)

### 2.8.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.6.0](https://fluentbit.io/announcements/v1.6.0/)
* Amazon CloudWatch Logs for Fluent Bit 1.4.1
* Amazon Kinesis Streams for Fluent Bit 1.6.1
* Amazon Kinesis Firehose for Fluent Bit 1.4.2

Compared to `2.7.0` this release adds:
* New Plugin - [`s3` plugin in Fluent Bit core](https://docs.fluentbit.io/manual/pipeline/outputs/s3) is a high performance replacement output that can send data directly to S3
* New Plugin - [`kinesis_firehose` plugin in Fluent Bit core](https://docs.fluentbit.io/manual/pipeline/outputs/firehose) is a high performance replacement for the `firehose` Golang plugin.
* Bug - Truncate records to max size in `cloudwatch`, `firehose`, and `kinesis` plugins
* Bug - Add back `auto_create_group` option [cloudwatch:96](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/96)

### 2.7.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.5.6](https://fluentbit.io/announcements/v1.5.6/)
* Amazon CloudWatch Logs for Fluent Bit 1.4.0
* Amazon Kinesis Streams for Fluent Bit 1.6.0
* Amazon Kinesis Firehose for Fluent Bit 1.4.1

Compared to `2.6.1` this release adds:
* Feature - Add support for zlib compression of records [kinesis:26](https://github.com/aws/amazon-kinesis-streams-for-fluent-bit/issues/26)
* Feature - Add KPL aggregation support [kinesis:16](https://github.com/aws/amazon-kinesis-streams-for-fluent-bit/issues/16)
* Feature - Add support for dynamic log group names [cloudwatch:46](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/46)
* Feature - Add support for dynamic log stream names [cloudwatch:16](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/16)
* Feature - Support tagging of newly created log groups [cloudwatch:51](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/51)
* Feature - Support setting log group retention policies [cloudwatch:50](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/50)

### 2.6.1
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.5.2](https://fluentbit.io/announcements/v1.5.2/)
* Amazon CloudWatch Logs for Fluent Bit 1.3.2
* Amazon Kinesis Streams for Fluent Bit 1.5.1
* Amazon Kinesis Firehose for Fluent Bit 1.4.1

### 2.6.0
This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.5.1](https://fluentbit.io/announcements/v1.5.1/)
* Amazon CloudWatch Logs for Fluent Bit 1.3.1
* Amazon Kinesis Streams for Fluent Bit 1.5.0
* Amazon Kinesis Firehose for Fluent Bit 1.4.0

Compared to `2.5.0` this release adds:
* Feature - Add `log_key` option support to `firehose`, and `kinesis` plugins.
* Bug - Add an empty check before sending log events to destinations for `firehose` and `cloudwatch` plugins.

### 2.5.0

This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.5.0](https://fluentbit.io/announcements/v1.5.0/)
* Amazon CloudWatch Logs for Fluent Bit 1.3.0
* Amazon Kinesis Streams for Fluent Bit 1.4.0
* Amazon Kinesis Firehose for Fluent Bit 1.3.0

Compared to `2.4.0` this release adds:
* Feature - Add `sts_endpoint` parameter to `cloudwatch`, `firehose`, and `kinesis` plugins to support specifying a custom STS API endpoint.

### 2.4.0

This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.5.0](https://fluentbit.io/announcements/v1.5.0/)
* Amazon CloudWatch Logs for Fluent Bit 1.2.0
* Amazon Kinesis Streams for Fluent Bit 1.3.0
* Amazon Kinesis Firehose for Fluent Bit 1.2.1

Compared to `2.3.1` this release adds:
* Feature - Add experimental concurrency feature in Kinesis plugin [kinesis:33](https://github.com/aws/amazon-kinesis-streams-for-fluent-bit/pull/33)
* Feature - Add support for [Amazon ElasticSearch with IAM auth in the core Fluent Bit `es` plugin](https://docs.fluentbit.io/manual/pipeline/outputs/elasticsearch).
* New Plugin - [`cloudwatch_logs` plugin in Fluent Bit core](https://docs.fluentbit.io/manual/pipeline/outputs/cloudwatch) is a high performance replacement for the `cloudwatch` Golang plugin.

### 2.3.1

This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.4.5](https://fluentbit.io/announcements/v1.4.5/)
* Amazon CloudWatch Logs for Fluent Bit 1.2.0
* Amazon Kinesis Streams for Fluent Bit 1.2.2
* Amazon Kinesis Firehose for Fluent Bit 1.2.1

Compared to `2.3.0` this release adds:
* Bug Fix - Remove redundant exponential backoff code from Firehose and Kinesis plugins [firehose:23](https://github.com/aws/amazon-kinesis-firehose-for-fluent-bit/issues/23)

### 2.3.0

This release includes:
* An Amazon Linux 2 Base
* Fluent Bit [1.4.2](https://fluentbit.io/announcements/v1.4.2/)
* Amazon CloudWatch Logs for Fluent Bit 1.2.0
* Amazon Kinesis Streams for Fluent Bit 1.2.1
* Amazon Kinesis Firehose for Fluent Bit 1.2.0

Compared to `2.2.0` this release adds:
* Bug Fix - Updated logic to calculate individual and maximum record size [kinesis:22](https://github.com/aws/amazon-kinesis-streams-for-fluent-bit/pull/22)


### 2.2.0

This release includes:
* An Amazon Linux 2 Base
* Fluent Bit 1.3.9
* Amazon CloudWatch Logs for Fluent Bit 1.2.0
* Amazon Kinesis Streams for Fluent Bit 1.2.0
* Amazon Kinesis Firehose for Fluent Bit 1.2.0

Compared to `2.1.1` this release adds:
* Feature -  Add time_key and time_key_format config options to add timestamp to records [firehose:9](https://github.com/aws/amazon-kinesis-firehose-for-fluent-bit/issues/9)
* Feature -  Add time_key and time_key_format config options to add timestamp to records [kinesis:17](https://github.com/aws/amazon-kinesis-streams-for-fluent-bit/pull/17)
* Feature - Add support for Embedded Metric Format [cloudwatch:27](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/27)


### 2.1.1

This release includes:
* An Amazon Linux 2 Base
* Fluent Bit 1.3.4
* Amazon CloudWatch Logs for Fluent Bit 1.1.1
* Amazon Kinesis Streams for Fluent Bit 1.1.0
* Amazon Kinesis Firehose for Fluent Bit 1.1.0

Compared to `2.1.0` this release adds:
* Bug - Discard and do not send empty messages [cloudwatch:40](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/pull/40)

### 2.1.0

This release includes:
* An Amazon Linux 2 Base
* Fluent Bit 1.3.4
* Amazon CloudWatch Logs for Fluent Bit 1.1.0
* Amazon Kinesis Streams for Fluent Bit 1.1.0
* Amazon Kinesis Firehose for Fluent Bit 1.1.0

Compared to `2.0.0` this release adds:
* Bug - Container exits with code 0 when it gracefully shuts down - [#11](https://github.com/aws/aws-for-fluent-bit/issues/11)
* Feature - Support IAM Roles for Service Accounts in Amazon EKS in all plugins
    * [kinesis:6](https://github.com/aws/amazon-kinesis-streams-for-fluent-bit/pull/6)
    * [firehose:17](https://github.com/aws/amazon-kinesis-firehose-for-fluent-bit/pull/17)
    * [cloudwatch:33](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/pull/33)
* Feature - Add `credentials_endpoint` to CloudWatch plugin - [cloudwatch:36](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/pull/36)
* Bug - A single CloudWatch Logs PutLogEvents request can not contain logs that span more than 24 hours - [cloudwatch:29](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/29)

### 2.0.0

**Note:** This is the first AWS for Fluent Bit release under our new versioning scheme; previously the image was versioned by the Fluent Bit version it contained. Please see the project README for an explanation of how we version this project.

This release includes:
* An Amazon Linux 2 Base
* Fluent Bit 1.3.3
* Amazon CloudWatch Logs for Fluent Bit 1.0.0
* Amazon Kinesis Streams for Fluent Bit 1.0.0
* Amazon Kinesis Firehose for Fluent Bit 1.0.0

Compared to `aws-for-fluent-bit:1.3.2` this release adds:
* Bug - Allow retries for creating log group - [cloudwatch:18](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/18)
* Feature - Add Fluent Bit plugin for Amazon Kinesis Data Streams - [kinesis:1](https://github.com/aws/amazon-kinesis-streams-for-fluent-bit/pull/1)
