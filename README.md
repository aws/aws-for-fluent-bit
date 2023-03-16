## AWS for Fluent Bit Docker Image

### Contents

- [Versioning FAQ](#versioning-faq)
- [Compliance and Patching](#compliance-and-patching)
- [Debugging Guide](troubleshooting/debugging.md)
- [Use Case Guide](use_cases/)
- [Public Images](#public-images)
    - [arm64 and x86 images](#arm64-and-amd64-images)
    - [Using the stable tag](#using-the-stable-tag)
    - [Using the init tag](#using-the-init-tag)
    - [Using SSM to find available versions](#using-ssm-to-find-available-versions)
    - [Using SSM Parameters in CloudFormation Templates](#using-ssm-parameters-in-cloudFormation-templates)
    - [Using image tags](#using-image-tags)
        - [Amazon ECR Public Gallery](#amazon-ecr-public-gallery)
        - [Docker Hub](#docker-hub)
        - [Amazon ECR](#amazon-ecr)
- [Plugins](#plugins)
- [Using the AWS Plugins outside of a container](#using-the-aws-plugins-outside-of-a-container)
- [Running aws-for-fluent-bit Windows containers](#running-aws-for-fluent-bit-windows-containers)
- [Development](#development)
    - [Releasing](#releasing)
    - [Developing Features in the AWS Plugins](#developing-features-in-the-aws-plugins)
- [Fluent Bit Examples](#fluent-bit-examples)
- [License](#license)


### Versioning FAQ

The version of the AWS for Fluent Bit image is not linked to the version of Fluent Bit which it contains.

**What does the version number signify?**

We use the standard `major.minor.patch` versioning scheme for our image, AKA Semantic Versioning. The initial release with this versioning scheme is `2.0.0`. An update to the patch version indicates backwards compatible bug fixes, a minor version change indicates new backwards compatible functionality, and a major version change indicates backwards incompatible changes.

The AWS for Fluent Bit image includes the following contents:
* A base image (currently Amazon Linux or Windows Server Core 2019 or Windows Server Core 2022)
* Fluent Bit
* Several Fluent Bit Go Plugins

A change in any one of these pieces would lead to a change in our version number.

**What about the 1.x image tags in your repositories?**

The AWS for Fluent Bit image was launched in July 2019. Between July and October of 2019 we simply versioned the image based on the version of Fluent Bit that it contained. During this time we released `1.2.0`, `1.2.2` and `1.3.2`.

The old versioning scheme was simple and it made it clear which version of Fluent Bit our image contained. However, it had a serious problem- how could we signify that we had changed the other parts of the image? If we did not update Fluent Bit, but updated one of the plugins, how would we signify this in a new release? There was no answer- we could only release an update when Fluent Bit released a new version. We ultimately realized this was unacceptable- bug fixes or new features in our plugins should not be tied to the Fluent Bit release cadence.

Thus, we moved to the a new versioning scheme. Because customers already are relying on the `1.x` tags, we have left them in our repositories. The first version with the new scheme is `2.0.0`. From now on we will follow semantic versioning- but the move from `1.3.2` did not follow semantic versioning. There are no backwards incompatible changes between `aws-for-fluent-bit:1.3.2` and `aws-for-fluent-bit:2.0.0`. Our release notes for `2.0.0` clearly explain the change.

**Does this mean you are diverging from fluent/fluent-bit?**

No. We continue to consume Fluent Bit from its main repository. We are not forking Fluent Bit.

### Compliance and Patching

**Q: Is AWS for Fluent Bit HIPAA Compliant?**

Fluent Bit can be used in a HIPAA compliant matter to send logs to AWS, even if the logs contain PHI. Please see the call outs in the [AWS HIPAA white paper for ECS](https://docs.aws.amazon.com/whitepapers/latest/architecting-hipaa-security-and-compliance-on-aws/amazon-ecs.html).  

**Q: What is the policy for patching AWS for Fluent Bit for vulnerabilities, CVEs and image scan findings?**

AWS for Fluent Bit uses ECR image scanning in its release pipeline and any scan that finds high or critical vulnerabilities will block a release: [scripts/publish.sh](https://github.com/aws/aws-for-fluent-bit/blob/mainline/scripts/publish.sh#L487)

If you find an issue from a scan on our latest images please follow the reporting guidelines below and we will work quickly to introduce a new release. To be clear, we do not patch existing images, we just will release a new image without the issue. The team uses [Amazon ECR Basic image scanning](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning-basic.html) and [Amazon ECR Enhanced scanning powered by AWS Inspector](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning-enhanced.html) as the primary source of truth for whether or not the image contains a vulnerability in a dependency. 

If your concern is about a vulnerability in the Fluent Bit upstream ([github.com/fluent/fluent-bit](https://github.com/fluent/fluent-bit/) open source code), please let us know as well. However, fixing upstream issues requires additional work and time because we must work closely with upstream maintainers to commit a fix and cut an upstream release, and then we can cut an AWS for Fluent Bit release. 

**Q: How do I report security disclosures?**

If you think you’ve found a potentially sensitive security issue, please do not post it in the Issues on GitHub.  Instead, please follow the instructions [here](https://aws.amazon.com/security/vulnerability-reporting/) or email AWS security directly at [aws-security@amazon.com](mailto:aws-security@amazon.com).

### Debugging Guide

[Please read the debugging.md](troubleshooting/debugging.md)

### Use Case Guide

[A set of tutorials on use cases that Fluent Bit can solve](use_cases/).

### Public Images

#### Linux Images
Each release updates the `latest` tag and adds a tag for the version of the image. The `stable` tag is also available which marks a release as the latest stable version.

#### Windows Images
For Windows images, we update the `windowsservercore-latest` tag and add a tag as `<VERSION>-windowsservercore`. The stable tag is available as `windowsservercore-stable`. We update all the supported versions each month when [Microsoft releases the latest security
patches for Windows](https://support.microsoft.com/en-gb/topic/windows-server-container-update-history-23c939c5-3ca5-3a16-27b8-d18e00d2408a).  


**Note:** Deploying `latest`/`windowsservercore-latest` to prod without going through a test stage first is not recommended.
#### arm64 and amd64 images

AWS for Fluent Bit currently distributes container images for arm64 and amd64 CPU architectures. Our images all use [mutli-archictecture tags](https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-multi-architecture-image.html). For example, this means that if you pull the `latest` tag on a Graviton instance, you would get the arm64 image build. 

For Windows, [we release images](#windows-images) only for amd64 CPU architecture of the following Windows releases-
- Windows Server 2019
- Windows Server 2022

#### Using the stable tag

A `stable`/`windowsservercore-stable` tag can be trusted that it is the latest version in which there are no high impact bugs in Fluent Bit. A release may be marked as stable if the following rules are all met:
* It has been out for at least 2 weeks or is a CVE patch with no Fluent Bit changes. Stable designation is based on the Fluent Bit code in the image; we bump stable for CVE fixes in dependencies in the image if the underlying Fluent Bit code is already designated as stable.
* No bugs have been reported in Fluent Bit which we expect will have high impact for AWS customers. This means bugs in the components that are most frequently used by AWS customers, such as the AWS outputs or the tail input.

#### Using the init tag

The `init` tags indicate that an image contains init process and supports multi-config. Init tag is used in addition to our other tags, e.g. `aws-for-fluent-bit:init-latest` means this is a latest released image supports multi-config. For more information about the usage of multi-config please see our [use case guide](https://github.com/aws/aws-for-fluent-bit/blob/mainline/use_cases/init-process-for-fluent-bit/README.md) and [FireLens example](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/multi-config-support).

Note: Windows images with init tag are not available at the moment.

#### Using SSM to find available versions

As of 2.0.0, there are SSM Public Parameters which allow you to see available versions. These parameters are available in every region that the image is available in. Any AWS account can query these parameters.

To see a list of available version tags, run the following command:

```
aws ssm get-parameters-by-path --path /aws/service/aws-for-fluent-bit/ --query 'Parameters[*].Name'
```

Example output:

```
[
    "/aws/service/aws-for-fluent-bit/latest"
    "/aws/service/aws-for-fluent-bit/windowsservercore-latest"
    "/aws/service/aws-for-fluent-bit/2.0.0"
    "/aws/service/aws-for-fluent-bit/2.0.0-windowsservercore"
]
```

To see the ECR repository ID for a given image tag, run the following:

```
$ aws ssm get-parameter --name /aws/service/aws-for-fluent-bit/2.0.0
{
    "Parameter": {
        "Name": "/aws/service/aws-for-fluent-bit/2.0.0",
        "Type": "String",
        "Value": "906394416424.dkr.ecr.us-east-1.amazonaws.com/aws-for-fluent-bit:2.0.0",
        "Version": 1,
        "LastModifiedDate": 1539908129.759,
        "ARN": "arn:aws:ssm:us-west-2::parameter/aws/service/aws-for-fluent-bit/2.0.0"
    }
}
```

#### Using SSM Parameters in CloudFormation Templates

You can use these SSM Parameters as parameters in your CloudFormation templates.

```
Parameters:
  FireLensImage:
    Description: Fluent Bit image for the FireLens Container
    Type: AWS::SSM::Parameter::Value<String>
    Default: /aws/service/aws-for-fluent-bit/latest
```

#### Using image tags

You should lock your deployments to a specific version tag. We guarantee that these tags will be immutable- once they are released the will not change. 
Windows images will be updated each month to include the latest security patches in the base layers but the contents of the image will not change in a tag. 


##### Amazon ECR Public Gallery

[aws-for-fluent-bit](https://gallery.ecr.aws/aws-observability/aws-for-fluent-bit)

Our images are available in Amazon ECR Public Gallery. We recommend our customers to download images from this public repo. You can get images with different tags by following command:

```
docker pull public.ecr.aws/aws-observability/aws-for-fluent-bit:<tag>
```

For example, you can pull the image with latest version by:

```
docker pull public.ecr.aws/aws-observability/aws-for-fluent-bit:latest
```

If you see errors for image pull limits, try log into public ECR with your AWS credentials:

```
aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws
```

You can check the [Amazon ECR Public official doc](https://docs.aws.amazon.com/AmazonECR/latest/public/get-set-up-for-amazon-ecr.html) for more details.

##### Docker Hub

[amazon/aws-for-fluent-bit](https://hub.docker.com/r/amazon/aws-for-fluent-bit/tags)

##### Amazon ECR

We also provide images in Amazon ECR for high availability. These images are available in almost every AWS region, included AWS Gov Cloud.

The official way to find the ECR image URIs for your region is to use the SSM Parameters. In your region, run the following command:

```
aws ssm get-parameters-by-path --path /aws/service/aws-for-fluent-bit/
```

### Plugins

We currently bundle the following projects in this image:
* [amazon-kinesis-firehose-for-fluent-bit](https://github.com/aws/amazon-kinesis-firehose-for-fluent-bit)
* [amazon-cloudwatch-logs-for-fluent-bit](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit)
* [amazon-kinesis-streams-for-fluent-bit](https://github.com/aws/amazon-kinesis-streams-for-fluent-bit)

### Using the AWS Plugins outside of a container

You can use the AWS Fluent Bit plugins with [td-agent-bit](https://docs.fluentbit.io/manual/installation/supported-platforms).

We provide a [tutorial](examples/fluent-bit/systems-manager-ec2/) on using SSM to configure instances with td-agent-bit and the plugins.

### Running `aws-for-fluent-bit` Windows containers
You can run `aws-for-fluent-bit` Windows containers using the image tags as specified under [Windows Images section](#windows-images). These are distributed as multi-arch images with the manifests for the supported Windows releases as specified above.

For more details about running Fluent Bit Windows containers in Amazon EKS, please visit our [blog post](https://aws.amazon.com/blogs/containers/centralized-logging-for-windows-containers-on-amazon-eks-using-fluent-bit/).

For more details about running Fluent Bit Windows containers in Amazon ECS, please visit our [blog post](https://aws.amazon.com/blogs/containers/centralized-logging-for-windows-containers-on-amazon-ecs-using-fluent-bit/). For running Fluent Bit as a Amazon ECS Service using `daemon` scheduling strategy, please visit our Amazon ECS [tutorial](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/tutorial-deploy-fluentbit-on-windows.html). For more details about using the AWS provided default configurations for Amazon ECS, please visit our [documentation](ecs_windows_forward_daemon/README.md).

**Note**: There is a known issue with networking failure when running Fluent Bit in Windows containers on `default` container network. Check out the guidance in our debugging guide for a [workaround to this issue](troubleshooting/debugging.md#networking-issue-with-windows-containers-when-using-async-dns-resolution-by-plugins).

### Development

#### Releasing

Use `make release` to build the image.
To run the integration tests, run `make integ-dev`. The `make integ-dev` command will run the integration tests for all of our plugins-
kinesis streams, kinesis firehose, and cloudwatch.

To run integration tests separately, execute `make integ-cloudwatch` or `make integ-kinesis` or `make integ-firehose`.

[Documentation on GitHub steps for releases](Release_Process.md).

#### Developing Features in the AWS Plugins

You can build a version of the image with code in your GitHub fork. To do so, you must need to set the following environment variables.
Otherwise, you will see an error message like the following one:
`fatal: repository '/kinesis-streams' or '/kinesis-firehose' or '/cloudwatch' does not exist.`

Set the following environment variables for CloudWatch:

```
export CLOUDWATCH_PLUGIN_CLONE_URL="Your GitHub fork clone URL"
export CLOUDWATCH_PLUGIN_BRANCH="Your branch on your fork"
```

Or for Kinesis Streams:
```
export KINESIS_PLUGIN_CLONE_URL="Your GitHub fork clone URL"
export KINESIS_PLUGIN_BRANCH="Your branch on your fork"
```

Or for Kinesis Firehose:
```
export FIREHOSE_PLUGIN_CLONE_URL="Your GitHub fork clone URL"
export FIREHOSE_PLUGIN_BRANCH="Your branch on your fork"
```

Then run `make cloudwatch-dev` or `make kinesis-dev` or `make firehose-dev` to build the image with your changes.

To run the integration tests on your code, execute `make integ-cloudwatch-dev` or `make integ-kinesis-dev` or `make integ-firehose-dev`.

## Fluent Bit Examples
Check out Fluent Bit examples from our [amazon-ecs-firelens-examples](https://github.com/aws-samples/amazon-ecs-firelens-examples#fluent-bit-examples) repo.

## License

This project is licensed under the Apache-2.0 License.
