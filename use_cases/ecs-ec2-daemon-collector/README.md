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

### Tutorial: Send all Container STDOUT & STDERR to Amazon CloudWatch Logs

### Tutorial: Send all Container, ECS Dataplane, Container Runtime, and host logs to Amazon CloudWatch Logs

### Tutorial: Send all Container STDOUT & STDERR to Amazon S3

### Tutorial: Send all Container, ECS Dataplane, Container Runtime, and host logs to Amazon S3

## Considerations and Warnings for running the Fluent Bit Daemon Collector on ECS EC2

### Common Issues

### Load Test Results

## DIY Guide: Use our built-in configurations to customize your log collection experience

### Using AWS for Fluent Bit init

### Built-in Configuration Files

#### Collector Inputs

This section contains a list of input files and their use case and required parameters, and volumes. These configuration files are built into AWS for Fluent Bit starting with version X.Y.Z/TODO. 

##### Container STDOUT and STDERR Logs
* `/ecs/daemon/inputs/task.conf`

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
