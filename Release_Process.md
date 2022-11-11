# Releasing AWS for Fluent Bit

Steps which must performed on GitHub before we put out any images.

### How to write Change log entries

The ECS CLI is a good example: https://github.com/aws/amazon-ecs-cli/blob/master/CHANGELOG.md

Note that the PR or issue associated with each change is listed. Use the issue number if an issue is associated with the change; if there is no issue, use the PR.

For the aws-for-fluent-bit image, the issues will likely be in one of the plugin repos; reference them in markdown like this:

```
* Feature - Allow retries for creating log group - [cloudwatch:18](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/issues/18)
```


List features as:

* “Enhancement” - a very small change or improvement. For our fluent bit plugins, something like “improve debug log messages” would be an enhancement.
* “Feature” - most additions will follow under this category. For our Fluent Bit plugins, any time we add a new config option would be a feature.
* “Bug” - a change which fixes something which was broken previously.


Any change log with a “Feature” should lead to a Minor version bump. A Change log with only “Enhancement” entries can have a patch version bump.

For more, learn about semantic versioning: https://semver.org/

### Before releasing the images

#### Cut “releases” of the AWS Fluent Bit Plugins

The first step before a release is freeze development on the Fluent Bit plugins. No new PRs will be merged until after the release CM has completed.

For every Fluent Bit plugin which has changes since the last AWS for Fluent Bit release, we will create a GitHub release, and a new Git Tag (the tag is auto-created with the GitHub release). We will follow SemVer.

We are not releasing binaries for the Fluent Bit plugins. We will have GitHub releases just because it makes it easy to track changes of the plugins over time.

Steps:

1. Submit a PR to update the Change log for the plugin.
2. Merge the PR (get an approval), and publish a GitHub release with the same contents as the Change log entry

_Example Change Log Entry_

```
## 1.1.0
* Add `log_group_key` field to allow the log group name to be dynamically chosen for each log record (#25)
```

#### Version Bump and Change Log for AWS For Fluent Bit

Submit a PR to update the version file (https://github.com/aws/aws-for-fluent-bit/blob/master/AWS_FOR_FLUENT_BIT_VERSION), along with Windows
version file (https://github.com/aws/aws-for-fluent-bit/blob/mainline/windows.versions). Then add an entry to the Changelog (https://github.com/aws/aws-for-fluent-bit/blob/master/CHANGELOG.md).

For the AWS for Fluent Bit Change log, you will copy the “Enhancement”, “Feature” and “Bug” items from the releases for each of the plugins. This is a convenience for customers- they only need to go to one place to see what is new with each release.

_Example Change Log Entry_
```
## 2.0.1

This release includes:

For Linux images:
* An Amazon Linux 2 Base
* Fluent Bit 1.3.2
* Amazon CloudWatch Logs for Fluent Bit 1.1.0
* Amazon Kinesis Streams for Fluent Bit 1.0.0
* Amazon Kinesis Firehose for Fluent Bit 1.0.0

For Windows images:
* Windows Server Core 2019 Base 
* Windows Server Core 2022 Base 
* Fluent Bit 1.9.9
* Amazon CloudWatch Logs for Fluent Bit 1.9.0
* Amazon Kinesis Streams for Fluent Bit 1.10.0
* Amazon Kinesis Firehose for Fluent Bit 1.7.0

Compared to 2.0.0 this release adds:
* Feature - add `log_group_key` in CloudWatch Plugin
```
#### Draft a GitHub Release

Draft (but do not publish) a GitHub release for the image.

*Tag Version:* v + the version. For example v2.0.1

*Release Title:* AWS for Fluent Bit 2.0.1

*Release Notes:* Same as the Change log entry.

#### Check the version

Run `make release` to run the image to check that the version and Fluent Bit version are correctly printed:

```
$ docker run -it amazon/aws-for-fluent-bit:latest
AWS for Fluent Bit Container Image Version 2.0.0
Fluent Bit v1.3.3
```

### Release

With those steps complete, the images can now be made public. Once the images and SSM Parameters are all public, publish the GitHub release.
