# Example: Install Fluent Bit and the AWS output plugins on Amazon Linux 2 via AWS Systems Manager

In this example, we will walk you through the installation of [Fluent Bit](https://fluentbit.io/documentation/0.8/installation/redhat_centos.html) on an Amazon Linux 2 EC2 instance along with the [amazon-cloudwatch-logs-for-fluent-bit](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit) and [amazon-kinesis-firehose-for-fluent-bit](https://github.com/aws/amazon-kinesis-firehose-for-fluent-bit) output plugins via an [AWS Systems Manager Document](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-ssm-docs.html).

#### Prerequisites

To get started you will need:

* [Docker](https://docs.docker.com/install/Docker) installed on your local machine.
* An [Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/dev/Welcome.html) bucket to store your Fluent Bit config files along with the AWS output plugins for Fluent Bit.

#### Instructions

An [AWS Sytems Manager Document](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-ssm-docs.html) (SSM Document) defines the actions that Systems Manager performs on your managed instances. Systems Manager includes more than a dozen pre-configured documents that you can use by specifying parameters at runtime. Documents use JavaScript Object Notation (JSON) or YAML, and they include steps and parameters that you specify.

SSM Documents have a concept of plugins that allow you to perform actions to perform on a managed instance. One of those plugins is [aws:DownloadContent](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-plugins.html) which allows you to download documents and scripts from remote locations including Amazon S3. This is where we will store the Fluent Bit config files along with the AWS output plugins for Fluent Bit. SSM will then be able to download these files onto managed instances when the document is run.

The first step is to get the AWS output plugins for Fluent Bit onto your local machine. You can either run `make` to build each plugin (instructions on are their respective GitHub repositories) or simply just copy them out of the official [AWS for Fluent Bit Docker Image](https://github.com/aws/aws-for-fluent-bit).

```
docker create -ti --name ssmdemo amazon/aws-for-fluent-bit:latest
docker cp ssmdemo:/fluent-bit/cloudwatch.so .
docker cp ssmdemo:/fluent-bit/firehose.so .
docker cp ssmdemo:/fluent-bit/kinesis.so .
docker stop ssmdemo
docker rm ssmdemo
```

Now you can simply upload the AWS output plugins along with the [plugins.conf](plugins.conf) and [td-agent-bit.conf](td-agent-bit.conf) files to your S3 bucket. You can reference the aws:downloadContent sections within the SSM Document for [ConfigureFluentBitEC2.yaml](ConfigureFluentBitEC2.yaml) to see how they are referenced. The example [td-agent-bit.conf](td-agent-bit.conf) for Fluent Bit is configured with the [Forward Input Plugin](https://docs.fluentbit.io/manual/input/forward) with the Output configured to send to Cloudwatch. 

Once that's done, you can then [create the SSM Document](https://docs.aws.amazon.com/systems-manager/latest/userguide/create-ssm-document-cli.html) for [ConfigureFluentBitEC2.yaml](ConfigureFluentBitEC2.yaml) to run against your managed instances.

Any other configurations for Fluent Bit would need to be configured and uploaded to the S3 bucket along with a section in the SSM Document to reference it.



