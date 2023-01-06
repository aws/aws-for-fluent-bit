# ECS EC2 Fluent Bit Daemon Log Collector Guide

The tutorials and templates in this guide will show you how to deploy Fluent Bit on an ECS EC2 Cluster as a Daemon Service that can optionally collect:
* Container Logs: Messages emitted to stdout/stderr from your containers
* ECS Dataplane logs: ECS Agent, ECS Init, ECS Volume and ENI Plugins, and ECS Audit logs
* Container runtime logs: Docker and Containerd logs in journald
* Host Logs: Cloud Init logs, `/var/log/messages`, `/var/log/dmesg`, and `/var/log/secure`

## Table of Contents 

* [Quickstart Guides: Deploy our templates in minutes](#quickstart-guides-deploy-our-templates-in-minutes)
    * [Prerequisites]
    * [Tutorial: Send all Container STDOUT & STDERR to Amazon CloudWatch Logs](#send-all-container-stdout--stderr-to-amazon-cloudwatch-logs)
    * [Tutorial: Send all Container, ECS Dataplane, Container Runtime, and host logs to Amazon CloudWatch Logs](#send-all-container-ecs-dataplane-container-runtime-and-host-logs-to-amazon-cloudwatch-logs)
    * [Tutorial: Send all Container STDOUT & STDERR to Amazon S3](#send-all-container-stdout--stderr-to-amazon-s3)
    * [Tutorial: Send all Container, ECS Dataplane, Container Runtime, and host logs to Amazon S3](#send-all-container-ecs-dataplane-container-runtime-and-host-logs-to-amazon-s3)
* [Considerations and Warnings for running the Fluent Bit Daemon Collector](#considerations-and-warnings-for-running-the-fluent-bit-daemon-collector)
    * [Common Issues](#common-issues)
    * [Monitoring the daemon collector](#monitoring-the-daemon-collector)
    * [Load Test Results](#load-test-results)
* [DIY Guide: Use our built-in configurations to customize your log collection experience](#diy-guide-use-our-built-in-configurations-to-customize-your-log-collection-experience)
    * [Using AWS for Fluent Bit init](#using-aws-for-fluent-bit-init)
    * [Built-in Configuration Files](#built-in-configuration-files)
        * [Collector Inputs](#collector-inputs)
        * [Collector Outputs for Amazon CloudWatch Logs](#collector-outputs-for-amazon-cloudwatch-logs)
        * [Collector Outputs for Amazon S3](#collector-outputs-for-amazon-s3)


## Quickstart Guides: Deploy our templates in minutes

### Prerequisites

* An Amazon ECS Cluster with capacity provided by instances running the [Amazon ECS Optimized Amazon Linux AMI](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html) - these guides have been tested on Amazon EC2 instances. You can only run an [Amazon ECS Daemon Service](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_services.html) with the `EC2` launch type.
* The daemon collector can collect logs emitted by your task/application containers to stdout/stderr.
* You must first configure your task containers to log to the json-file log driver. This can be done by adding the following for the [logConfiguration](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_LogConfiguration.html) of each container definition in your task definitions:

```
"logConfiguration": {
                "logDriver": "json-file",
                "options": {
                    "max-file": "2",
                    "max-size": "10m"
                }
            }
```

### Tutorial: Send all Container STDOUT & STDERR to Amazon CloudWatch Logs

Please read the [Prerequisites](#prerequisites) section of this guide before following this tutorial.

#### Log Group and Stream Names

#### Log Metadata

#### Using the Task Definition Template


Next, please read the [Considerations and Warnings for running the Fluent Bit Daemon Collector](#considerations-and-warnings-for-running-the-fluent-bit-daemon-collector) section.

#### Using the CloudFormation Template

### Tutorial: Send all Container, ECS Dataplane, Container Runtime, and host logs to Amazon CloudWatch Logs

### Tutorial: Send all Container STDOUT & STDERR to Amazon S3

### Tutorial: Send all Container, ECS Dataplane, Container Runtime, and host logs to Amazon S3

## Considerations and Warnings for running the Fluent Bit Daemon Collector on ECS EC2

### Common Issues

1. (TODO: add example error message) CloudWatch Rejects log events because they are too old. (Doc Link). If you have [READ_FROM_HEAD parameter](https://docs.fluentbit.io/manual/pipeline/inputs/tail) set to `On`, and you have older logs on disk, you may see that logs fail to upload. 

### Monitoring the daemon collector

### Load Test Results

## DIY Guide: Use our built-in configurations to customize your log collection experience

### Using AWS for Fluent Bit init

### Built-in Configuration Files

#### Collector Inputs

This section contains a list of input files and their use case and required parameters, and volumes. These configuration files are built into AWS for Fluent Bit starting with version X.Y.Z/TODO. 

##### Container STDOUT and STDERR Logs
* `/ecs/daemon/inputs/task.conf`
    * **Use Case**: Collect all stdout & stderr logs from containers
    * **Required Host Mount Volume**: `/var/lib/docker/containers`
    * **Parameters**
        * `READ_FROM_HEAD_TASKLOGS` - For the Fluent Bit [READ_FROM_HEAD parameter](https://docs.fluentbit.io/manual/pipeline/inputs/tail), `On` means read all logs present on disk (from the head of the file) at collector start time, `Off` means only read logs written to the file after collector start time (from the tail of the file).
        * `MEM_BUF_LIMIT_TASK` - The Fluent Bit [MEM_BUF_LIMIT parameter](https://docs.fluentbit.io/manual/administration/buffering-and-storage) limits the amount of memory that an input can use to collect logs. The default of `50M` (50 megabytes) in our templates should be sufficient for most users. If you see [overlimit warnings](https://github.com/aws/aws-for-fluent-bit/blob/mainline/troubleshooting/debugging.md#overlimit-warnings) then you need to increase it.



##### Container Runtime Logs
* `/ecs/daemon/inputs/runtime.conf`

##### ECS Dataplane Logs
* `/ecs/daemon/inputs/ecs/all-ecs-dataplane.conf`
* `/ecs/daemon/inputs/ecs/agent.conf`
* `/ecs/daemon/inputs/ecs/audit.conf`
* `/ecs/daemon/inputs/ecs/cni-bridge-plugin.conf`
* `/ecs/daemon/inputs/ecs/cni-eni-plugin.conf`
* `/ecs/daemon/inputs/ecs/init.conf`
* `/ecs/daemon/inputs/ecs/volume-plugin.conf`
* `/ecs/daemon/inputs/ecs/vpc-branch-eni.conf`

##### Host Logs

* `/ecs/daemon/inputs/host/all-host.conf`
* `/ecs/daemon/inputs/host/cloud-init.conf`
* `/ecs/daemon/inputs/host/var-log/dmesg.conf`
* `/ecs/daemon/inputs/host/var-log/messages.conf`
* `/ecs/daemon/inputs/host/var-log/secure.conf`

#### Collector Outputs for Amazon CloudWatch Logs

* `/ecs/daemon/outputs/cloudwatch_logs/ecs.conf`
* `/ecs/daemon/outputs/cloudwatch_logs/host.conf`
* `/ecs/daemon/outputs/cloudwatch_logs/runtime.conf`
* `/ecs/daemon/outputs/cloudwatch_logs/task.conf`

#### Collector Outputs for Amazon S3
