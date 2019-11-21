## AWS for Fluent Bit Docker Image

### Public Images

There are image tags for `latest` and the version of Fluent Bit that is built in the image. The first release is Fluent Bit `1.2.0`.

##### Docker Hub

[amazon/aws-for-fluent-bit](https://hub.docker.com/r/amazon/aws-for-fluent-bit/tags)

##### Amazon ECR

We also provide images in Amazon ECR in each AWS Region for high availability.

| Region         | Registry ID  | Full Image URI                                                          |
|----------------|--------------|-------------------------------------------------------------------------|
| us-east-1      | 906394416424 | 906394416424.dkr.ecr.us-east-1.amazonaws.com/aws-for-fluent-bit:latest      |
| eu-west-1      | 906394416424 | 906394416424.dkr.ecr.eu-west-1.amazonaws.com/aws-for-fluent-bit:latest      |
| us-west-1      | 906394416424 | 906394416424.dkr.ecr.us-west-1.amazonaws.com/aws-for-fluent-bit:latest      |
| ap-southeast-1 | 906394416424 | 906394416424.dkr.ecr.ap-southeast-1.amazonaws.com/aws-for-fluent-bit:latest |
| ap-northeast-1 | 906394416424 | 906394416424.dkr.ecr.ap-northeast-1.amazonaws.com/aws-for-fluent-bit:latest |
| us-west-2      | 906394416424 | 906394416424.dkr.ecr.us-west-2.amazonaws.com/aws-for-fluent-bit:latest      |
| sa-east-1      | 906394416424 | 906394416424.dkr.ecr.sa-east-1.amazonaws.com/aws-for-fluent-bit:latest      |
| ap-southeast-2 | 906394416424 | 906394416424.dkr.ecr.ap-southeast-2.amazonaws.com/aws-for-fluent-bit:latest |
| eu-central-1   | 906394416424 | 906394416424.dkr.ecr.eu-central-1.amazonaws.com/aws-for-fluent-bit:latest   |
| ap-northeast-2 | 906394416424 | 906394416424.dkr.ecr.ap-northeast-2.amazonaws.com/aws-for-fluent-bit:latest |
| ap-south-1     | 906394416424 | 906394416424.dkr.ecr.ap-south-1.amazonaws.com/aws-for-fluent-bit:latest     |
| us-east-2      | 906394416424 | 906394416424.dkr.ecr.us-east-2.amazonaws.com/aws-for-fluent-bit:latest      |
| ca-central-1   | 906394416424 | 906394416424.dkr.ecr.ca-central-1.amazonaws.com/aws-for-fluent-bit:latest   |
| eu-west-2      | 906394416424 | 906394416424.dkr.ecr.eu-west-2.amazonaws.com/aws-for-fluent-bit:latest      |
| eu-west-3      | 906394416424 | 906394416424.dkr.ecr.eu-west-3.amazonaws.com/aws-for-fluent-bit:latest      |
| ap-northeast-3 | 906394416424 | 906394416424.dkr.ecr.ap-northeast-3.amazonaws.com/aws-for-fluent-bit:latest |
| eu-north-1     | 906394416424 | 906394416424.dkr.ecr.eu-north-1.amazonaws.com/aws-for-fluent-bit:latest     |
| ap-east-1      | 449074385750 | 449074385750.dkr.ecr.ap-east-1.amazonaws.com/aws-for-fluent-bit:latest      |
| cn-north-1     | 128054284489 | 128054284489.dkr.ecr.cn-north-1.amazonaws.com/aws-for-fluent-bit:latest     |
| cn-northwest-1 | 128054284489 | 128054284489.dkr.ecr.cn-northwest-1.amazonaws.com/aws-for-fluent-bit:latest |
| us-gov-east-1  | 161423150738 | 161423150738.dkr.ecr.us-gov-east-1.amazonaws.com/aws-for-fluent-bit:latest  |
| us-gov-west-1  | 161423150738 | 161423150738.dkr.ecr.us-gov-west-1.amazonaws.com/aws-for-fluent-bit:latest  |

### Development

#### Releasing

Use `make release` to build the image. To run the integration tests, run `make integ`.

#### Developing Features in the AWS Plugins

You can build a version of the image with code in your GitHub fork.

Set the following environment variables for CloudWatch:

```
export CLOUDWATCH_PLUGIN_CLONE_URL="Your GitHub fork clone URL"
export CLOUDWATCH_PLUGIN_BRANCH="Your branch on your fork"
```

Or for Firehose:
```
export CLOUDWATCH_PLUGIN_CLONE_URL="Your GitHub fork clone URL"
export CLOUDWATCH_PLUGIN_BRANCH="Your branch on your fork"
```

Or for Kinesis
```
export CLOUDWATCH_PLUGIN_CLONE_URL="Your GitHub fork clone URL"
export CLOUDWATCH_PLUGIN_BRANCH="Your branch on your fork"
```

Then run `make cloudwatch-dev` or `make firehose-dev` or `make kinesis-dev` to build the image with your changes.

To run the integration tests on your code, run `make integ-cloudwatch-dev` or `make integ-firehose-dev` or `make integ-kinesis-dev`.

## License

This project is licensed under the Apache-2.0 License.
