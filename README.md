## AWS for Fluent Bit Docker Image

Welcome to AWS for Fluent Bit! Before using this Docker Image, please read this README entirely, **especially the section on [Consuming AWS for Fluent Bit versions](#consuming-aws-for-fluent-bit-versions)** 🫡

### Contents

- [Consuming AWS for Fluent Bit versions](#consuming-aws-for-fluent-bit-versions)
    - [AWS Distro for Fluent Bit Release Tags](#aws-distro-for-fluent-bit-release-tags)
    - [AWS Distro for Fluent Bit release testing](#aws-distro-for-fluent-bit-release-testing)
    - [Latest stable version](#latest-stable-version)
    - [CVE scans and latest stable](#cve-scans-and-latest-stable)
    - [Guidance on consuming versions](#guidance-on-consuming-versions)
- [AWS Distro versioning scheme FAQ](#aws-distro-versioning-scheme-faq)
- [Compliance and Patching](#compliance-and-patching)
- [Debugging Guide](troubleshooting/debugging.md)
- [Use Case Guide](use_cases/)
- [Public Images](#public-images)
    - [arm64 and x86 images](#arm64-and-amd64-images)
    - [Using the init tag](#using-the-init-tag)
    - [Using SSM to find available versions and aws regions](#using-ssm-to-find-available-versions-and-aws-regions)
    - [Using SSM Parameters in CloudFormation Templates](#using-ssm-parameters-in-cloudFormation-templates)
    - [Using image tags](#using-image-tags)
        - [Amazon ECR Public Gallery](#amazon-ecr-public-gallery)
        - [Docker Hub](#docker-hub)
        - [Amazon ECR](#amazon-ecr)
    - [Using the debug images](#Using-the-debug-images)
- [Plugins](#plugins)
- [Using the AWS Plugins outside of a container](#using-the-aws-plugins-outside-of-a-container)
- [Running aws-for-fluent-bit Windows containers](#running-aws-for-fluent-bit-windows-containers)
- [Development](#development)
    - [Local testing](#local-testing)
    - [Developing Features in the AWS Plugins](#developing-features-in-the-aws-plugins)
- [Fluent Bit Examples](#fluent-bit-examples)
- [License](#license)


### Consuming AWS for Fluent Bit versions

> 🔥⚠️**WARNING**⚠️🔥: Please read and understand the following information on how to consume AWS for Fluent Bit. Failure to do so may cause outages to your production environment. 😭💔

#### AWS Distro for Fluent Bit Release Tags

Our image repos contain the following types of tags, which are explained in the sections below:

* `latest`: The most recently released image version. 🔥 **😵We do not recommend deploying this to production environments ever,** see [Guidance on consuming versions](#guidance-on-consuming-versions).
* `Version number tag`: Each release has a version number, for example `2.28.4`. **These are the only tags we recommend ✅😍 consuming in production environments**: [Guidance on consuming versions](#guidance-on-consuming-versions).
* `stable`: Some time after a version is released, it may be designated as the latest stable. See [Latest stable version](#latest-stable-version) and  [Guidance on consuming versions](#guidance-on-consuming-versions).

#### AWS Distro for Fluent Bit release testing

**Types of tests we run**

* [Simple integration tests](https://github.com/aws/aws-for-fluent-bit/tree/mainline/integ): Short running tests of the AWS output plugins that send log records and verify that all of them were received correctly formatted at the destination.
* [Load Tests:](https://github.com/aws/aws-for-fluent-bit/tree/mainline/load_tests) Test Fluent Bit AWS output plugins at various throughputs and check for log loss, the results are posted in our release notes: https://github.com/aws/aws-for-fluent-bit/releases
* Long running stability tests: Highly parallel tests run in Amazon ECS for the AWS output plugins using the [aws/firelens-datajet](https://github.com/aws/firelens-datajet) project. These tests simulate real Fluent Bit deployments and use cases to test for bugs that crashes. 


**Latest release testing bar**

* [Simple integration tests](https://github.com/aws/aws-for-fluent-bit/tree/mainline/integ): Must fully pass with all log events received properly formatted at the destination. 
* [Load Tests:](https://github.com/aws/aws-for-fluent-bit/tree/mainline/load_tests) Must pass the [thresholds here](https://github.com/aws/aws-for-fluent-bit/blob/mainline/load_tests/validation_bar.py). Results are posted in our release notes: https://github.com/aws/aws-for-fluent-bit/releases
* Long running stability tests: No crashes observed for at least 1 day. 


**CVE Patch release testing bar**

* [Simple integration tests](https://github.com/aws/aws-for-fluent-bit/tree/mainline/integ): Must fully pass with all log events received properly formatted at the destination. 
* [Load Tests:](https://github.com/aws/aws-for-fluent-bit/tree/mainline/load_tests) Must pass the [thresholds here](https://github.com/aws/aws-for-fluent-bit/blob/mainline/load_tests/validation_bar.py). Results are posted in our release notes: https://github.com/aws/aws-for-fluent-bit/releases

We do not run our long running stability tests for CVE patches. This is because the goal is to get the CVE patch out as quickly as possible, and because CVE patch releases never include Fluent Bit code changes. CVE patch releases only include base image dependency upgrades. *If there is ever a CVE in the Fluent Bit code base itself, the patch for it would be considered a bug fix that might introduce instability and it would undergo the normal latest release testing.* 

**Latest stable release testing bar**

For a version to be made the latest `stable`, it must already have been previously released as the latest release. Thus it will have already passed the testing bar noted above for `latest`. 

In addition, our stable release undergoes additional testing:

* Long running stability tests: The version undergoes and passes these tests for at least 2 weeks. After the version is promoted to stable we continue to run the long running stability tests, and may roll back the stable designation if issues later surface.  

#### Latest stable version

Our latest stable version is the most recent version that we have high confidence is stable for AWS use cases. *We recommend using the stable version number in your prod deployments but **not the stable tag itself**; see* [Guidance on consuming versions](#guidance-on-consuming-versions)

The latest stable version is marked with the tag `stable`/`windowsservercore-stable`. The version number that is currently designated as the latest stable can always be found in the [AWS_FOR_FLUENT_BIT_STABLE_VERSION](https://github.com/aws/aws-for-fluent-bit/blob/mainline/AWS_FOR_FLUENT_BIT_STABLE_VERSION) file in the root of this repo. 

> ❗ *There is no guarantee that `stable` has no issues- stable simply has a higher testing bar than our latest releases. The `stable` tag can be downgraded and rolled back to the previous stable if new test results or customer bug reports surface issues. This has occurred* [*in the past*](https://github.com/aws/aws-for-fluent-bit/issues/542)*.  *Consequently, we recommend locking to a **specific version tag** and informing your choice of version using our current stable designation.*


Prior to being designated as the latest stable, a version must pass the following criteria:

* It has been out for at least 2 weeks or is a CVE patch with no Fluent Bit changes. Stable designation is based on the Fluent Bit code in the image. A version released for CVE patches can be made stable if the underlying if the underlying Fluent Bit code is already designated as stable.
* No bugs have been reported in Fluent Bit which we expect will have high impact for AWS customers. This means bugs in the components that are most frequently used by AWS customers, such as the AWS outputs or the tail input.
* The version has passed our long running stability tests for at least 2 weeks. The version would have already passed our simple integration and load tests when it was first released as the latest image. 

#### CVE scans and latest stable

[Please read our CVE patching policy.](https://github.com/aws/aws-for-fluent-bit#compliance-and-patching) 

The stable designation is for the Fluent Bit code contents of the image, not CVE scan results for dependencies installed in the image. We will upgrade a CVE patch to be the latest stable if it contains no Fluent Bit code changes compared to the previous latest stable. 


#### Guidance on consuming versions

Our [release notes](https://github.com/aws/aws-for-fluent-bit/releases) call out the key AWS changes in each new version. 

*We recommend that you only consume non-stable releases in your test/pre-prod stages. Consuming the `latest` tag directly is widely considered to be an anti-pattern in the software industry.* 

⚡ *We strongly recommend that you always lock deployments to a specific immutable version tag, rather than using our `stable` or `latest` tags.* We recommend you to conduct a gradual rollout of each new version consistent with your deployment rollout strategy as you would for any other code or dependency being deployed: i.e. first to non-production environments first then gradually to your production environments.

Using the `stable` or `latest` tag directly in prod has the following downsides: 🤕

1. 😕*Difficulty in determining which version was deployed*: If you experience an issue, you will need to [check the Fluent Bit log output to determine which specific version tag](https://github.com/aws/aws-for-fluent-bit/blob/mainline/troubleshooting/debugging.md#what-version-did-i-deploy) was deployed. This is because the `stable` and `latest` tags are mutable and change over time. 
2. 😐*Mixed deployments*: If you are in the middle of a deployment when we release an update to the `stable` or `latest` immutable tags, some of your deployment may have deployed the previous version, and the rest will deploy the new version. 
3. 🤢*Difficulty in rolling back*: While we take every effort to avoid releasing regressions, there is always a chance a bug might slip out. Explicitly consuming a version helps make it easier to rollback since there would be an existing deployment configuration to rollback to.


*The best practice for consuming AWS for Fluent Bit is to check the [AWS_FOR_FLUENT_BIT_STABLE_VERSION](https://github.com/aws/aws-for-fluent-bit/blob/mainline/AWS_FOR_FLUENT_BIT_STABLE_VERSION) file and lock your prod deployments to that specific version tag.* For example, if the current stable is `2.28.4`, your deployment should use `public.ecr.aws/aws-observability/aws-for-fluent-bit:2.28.4` not `public.ecr.aws/aws-observability/aws-for-fluent-bit:stable`.


### AWS Distro versioning scheme FAQ

The version of the AWS for Fluent Bit image is not linked to the version of Fluent Bit which it contains.

**What does the version number signify?**

We use the standard `major.minor.patch` versioning scheme for our image, AKA Semantic Versioning. The initial release with this versioning scheme is `2.0.0`. Bug fixes are released in patch version bumps. New features are released in new minor versions. We strive to only release backwards incompatible changes in new major versions.

Please read the below on CVE patches in base images and dependencies. The semantic version number applies to the Fluent Bit code and [AWS Go plugin](https://github.com/aws/aws-for-fluent-bit/blob/mainline/troubleshooting/debugging.md#aws-go-plugins-vs-aws-core-c-plugins) code compiled and installed in the image.

**Image Versions and CVE Patches**

The AWS for Fluent Bit image includes the following contents:
* A base image (currently Amazon Linux or Windows Server Core 2019 or Windows Server Core 2022)
* Runtime dependencies installed on top of the base image
* Fluent Bit binary
* Several Fluent Bit [Go Plugin binaries](https://github.com/aws/aws-for-fluent-bit/blob/mainline/troubleshooting/debugging.md#aws-go-plugins-vs-aws-core-c-plugins)

The process for pushing out new builds with CVE patches in the base image or installed dependencies is different for Windows vs Linux. 

For Windows, every month after the [B release date/"patch tuesday"](https://learn.microsoft.com/en-us/windows/deployment/update/release-cycle#monthly-security-update-release), we re-build and update all Windows images currently found in the [windows.versions](windows.versions) file in this repo with the newest base images from Microsoft. The Fluent Bit and go plugin binaries are copied into the newly released base windows image. Thus, the windows image tags are not immutable images; only the Fluent Bit and Go plugin binaries are immutable over time.

For Linux, each image tag is immutable. When there is a report of high or critical CVEs reported in the base amazon linux image or installed linux packages, we will work to push out a new image [per our patching policy](#compliance-and-patching). However, we will not increment the semantic version number to simply re-build to pull in new linux dependencies. Instead, we will add a 4th version number signifying the date the image was built.

For example, a series of releases in time might look like:

1. `2.31.12`: New Patch release with changes in Fluent Bit code compared to `2.31.11`. This release will have standard release notes and will have images for both linux and windows. 
2. `2.31.12-20230629`: Re-build of `2.31.12` just for Linux CVEs found in the base image or installed dependencies. The Fluent Bit code contents are the same as `2.31.12`. There only be linux images with this version tag, and no windows images. The `latest` tag for linux will be updated to point to this new image. There will be short release notes that call out it is simply a re-build for linux. 
3. `2.31.12-20230711`: Another re-build of `2.31.12` for Linux CVEs on a subsequent date. This release is special as explained above in the way same as `2.31.12-20230629`.
4. `2.31.13`: New Patch release with changes in Fluent Bit code compared to `2.31.12`. This might be for bugs found in the Fluent Bit code. It could also be for a CVE found in the Fluent Bit code. This release has standard release notes and linux and windows images. 


**Why do some image tags contain 4 version numbers?**

Please see the above explanation on our Linux image re-build process for CVEs found in dependencies. 

**Are there edge cases to the rules on breaking backwards compatibility?**

One edge case for the above semantic versioning rules is changes to configuration validation. Between Fluent Bit upstream versions 1.8 and 1.9, validation of config options was fixed/improved. Previous to this distro's upgrade to Fluent Bit upstream 1.9, configurations that included certain invalid options would run without error (the invalid options were ignored). After we released Fluent Bit usptream 1.9 support, these invalid options were validated and Fluent Bit would exit with an error. See the [issue discussion here](https://github.com/aws/aws-for-fluent-bit/issues/371#issuecomment-1160663682). 

Another edge case to the above rules are bug fixes that require removing a change. We have and will continue to occasionally remove new changes in a patch version if they were found to be buggy. We do this to unblock customers who do not depend on the recent change. Please always check our release notes for the changes in a specific version. A past example of a patch release that removed something is [2.31.4](https://github.com/aws/aws-for-fluent-bit/releases/tag/v2.31.4). A prior release had fixed how S3 handles the timestamps in S3 keys and the `Retry_Limit` configuration option. Those changes were considered to be bug fixes. However, they introduced instability so we subsequently removed them in a patch. 


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

#### Using the init tag

The `init` tags indicate that an image contains init process and supports multi-config. Init tag is used in addition to our other tags, e.g. `aws-for-fluent-bit:init-latest` means this is a latest released image supports multi-config. For more information about the usage of multi-config please see our [use case guide](https://github.com/aws/aws-for-fluent-bit/blob/mainline/use_cases/init-process-for-fluent-bit/README.md) and [FireLens example](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/multi-config-support).

Note: Windows images with init tag are not available at the moment.

#### Using SSM to find available versions and aws regions

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

If there is no output, it means the aws for fluent bit image is not available in current region.

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

If you see errors for image pull limits, or get the following error:

```
Error response from daemon: pull access denied for public.ecr.aws/amazonlinux/amazonlinux, repository does not exist or may require 'docker login': denied: Your authorization token has expired. Reauthenticate and try again.
```

Then try log into public ECR with your AWS credentials:

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

#### Using the debug images

Deploying AWS for Fluent Bit debug images can help the AWS team troubleshoot an issue. If you experience a bug, especially a [crash/SIGSEGV issue](https://github.com/aws/aws-for-fluent-bit/blob/mainline/troubleshooting/debugging.md#caught-signal-sigsegv), then please consider deploying the debug version of the image. After a crash, the debug image can print out a stacktrace and upload a core dump to S3. See our [debugging guide](https://github.com/aws/aws-for-fluent-bit/blob/mainline/troubleshooting/debugging.md#1-build-and-distribute-a-core-dump-s3-uploader-image) for more info on using debug images.

For debug images, we update the `debug-latest` tag and add a tag as `debug-<Version>`.

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

#### Local integ testing

Use `make dev` to build the image.

The `make integ-dev` command will run the integration tests for all of our plugins-
kinesis streams, kinesis firehose, and cloudwatch.

Note that these steps rely on creating Cfn stacks in an AWS account in region us-west-2,
so AWS credentials must be setup before they are run.

Instructions:
1. Setup AWS access via EC2 instance role or AWS_* env vars
2. Install dependent packages: `docker awscli`
3. Install docker-compose:
```
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```
4. Build validator images:
```
pushd integ/validate_cloudwatch && docker build -t flbcwinteg . && popd
pushd integ/s3 && docker build -t flbs3integ . && popd
export CW_INTEG_VALIDATOR_IMAGE="flbcwinteg"
export S3_INTEG_VALIDATOR_IMAGE="flbs3integ"
```
5. Run `make integ-dev`

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
