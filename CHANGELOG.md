# Changelog

Compared to `2.23.3` this release adds:
* Go version upgrade to 1.17.9

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
