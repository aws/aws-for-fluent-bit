# Changelog

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
