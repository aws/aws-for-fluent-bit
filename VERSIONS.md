# AWS for Fluent Bit Versions

We follow [Semantic Versioning](https://semver.org/), for our images using:
- MAJOR version when you make incompatible API changes
- MINOR version when you add functionality in a backward compatible manner
- PATCH version when you make backwards compatible bug fixes, or add backwards-compatible functionality which does not currently have a stable API or behavior
- BUILD version when you import backwards-compatible updates and/or CVE fixes from dependency packages (e.g. AL2), but do not modify aws-for-fluent-bit code or behavior

## Fluent Bit Versions

The version of the AWS for Fluent Bit image is not linked to the version of Fluent Bit which it contains.

Example: https://github.com/aws/aws-for-fluent-bit/releases/tag/v2.33.2
 
> Fluent Bit [1.9.10](https://github.com/fluent/fluent-bit/tree/v1.9.10)

## Software Versions

For images built after version `2.33.2`, we have added docker labels to help identify what software versions are in the container image for:
- AWS for Fluent Bit - `version` and `org.opencontainers.image.version` labels
- AmazonLinux - `com.aws-for-fluent-bit.os.version` label
- fluent-bit - `com.aws-for-fluent-bit.fluent-bit.version` label

To observe these labels it is necessary to:
1. Pull the image locally - `docker pull public.ecr.aws/aws-observability/aws-for-fluent-bit:latest`
2. Inspect the image
    - (Linux) `docker inspect public.ecr.aws/aws-observability/aws-for-fluent-bit:latest --format='{{json .Config.Labels}}' | jq -C '.'`
    - (Windows) `docker inspect public.ecr.aws/aws-observability/aws-for-fluent-bit:latest --format='{{json .Config.Labels}}' | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Out-Host
`
3. Validate the labels

Example Labels
```
{
  "author": "FireLens Team <aws-firelens@amazon.com>",
  "com.aws-for-fluent-bit.fluent-bit.version": "1.9.10",
  "com.aws-for-fluent-bit.os.image-id": "amzn2-container-raw-2.0.20250910.0-x86_64",
  "com.aws-for-fluent-bit.os.version": "Amazon Linux 2",
  "org.opencontainers.image.authors": "FireLens Team <aws-firelens@amazon.com>",
  "org.opencontainers.image.description": "AWS for Fluent Bit is the official AWS distribution of Fluent Bit. It is fully compatible with upstream Fluent Bit and is designed to be used on AWS environments like Amazon ECS and Amazon EKS.",
  "org.opencontainers.image.documentation": "https://github.com/aws/aws-for-fluent-bit",
  "org.opencontainers.image.licenses": "Apache-2.0",
  "org.opencontainers.image.source": "https://github.com/aws/aws-for-fluent-bit",
  "org.opencontainers.image.title": "AWS for Fluent Bit",
  "org.opencontainers.image.url": "https://gallery.ecr.aws/aws-observability/aws-for-fluent-bit",
  "org.opencontainers.image.vendor": "Amazon Web Services",
  "org.opencontainers.image.version": "2.34.0",
  "vendor": "Amazon Web Services",
  "version": "2.34.0"
}
```

## Linux Package Versions

To get a full listing of installed package versions, run: `docker run public.ecr.aws/aws-observability/aws-for-fluent-bit:3.0.0 grep "Installed:" /var/log/dnf.log /var/log/yum.log 2>/dev/null | sed 's/.*Installed: //'`. This can be useful to determine if a specific version is affected by a CVE.

## Version 3.0.0

With the upcoming release of AWS for Fluent Bit 3.0.0 we expect to introduce the following changes:
1. Migration from AL2 to AL2023
    - We are aware of the upcoming End of Life, EOL for AL2 on 2026-06-30[^1]
    - We want to take advantage of bare-bones AL2023 container images to reduce CVE risk we observed AL2 based AWS for Fluent Bit images
2. Migration from fluent-bit 1.9.10 to 4.x
    - We are aware of many changes our customers have been asking for from newer versions[^2]
    - We do not want to continue managing backports to 1.9.10 via [upstream-to-fluent-bit](https://github.com/amazon-contributing/upstream-to-fluent-bit)

### Adding Packages

As 3.x images are based on [minimal scratch images](https://docs.aws.amazon.com/linux/al2023/ug/barebones-containers.html), there may be packages missing for your specific use case. To add those packages, it is recommended to follow the multi-stage build approach shown in [runtime/Dockerfile.deps-al2023](https://github.com/aws/aws-for-fluent-bit/blob/mainline/scripts/dockerfiles/runtime/Dockerfile.deps-al2023):

```
FROM public.ecr.aws/amazonlinux/amazonlinux:2023 as dependencies

# Create sysroot directory and install minimal runtime dependencies
RUN mkdir /sysroot && \
    dnf --releasever=$(rpm -q system-release --qf '%{VERSION}') \
    --installroot /sysroot \
    -y \
    --setopt=install_weak_deps=False \
    install \
        # Add your required packages here, e.g.:
        # jq \
        # dnf

# Final minimal runtime image using aws-for-fluent-bit as base
FROM public.ecr.aws/aws-observability/aws-for-fluent-bit:3.0.0

# Copy the complete sysroot with all runtime dependencies
COPY --from=dependencies /sysroot /
```

To complete the custom image:
1. Save the Dockerfile with additional packages
2. Build the image with `docker build -t my-org/aws-fluent-bit-custom:3.0.0 .`
3. Publish and run

## Sample Versions 

Below is a table providing a small set of versions with the bump type and reason.

| Version | Release Notes | Bump | Reason |
|---------|---------------|------|--------|
| 2.32.5.20250626 | [v2.32.5.20250626](https://github.com/aws/aws-for-fluent-bit/releases/tag/v2.32.5.20250626) | BUILD | Amazon Linux base container image version: 2.0.20250623.0 |
| 2.33.0 | [v2.33.0](https://github.com/aws/aws-for-fluent-bit/releases/tag/v2.33.0) | MINOR | Feature: Add support for non-root user mode to the init image |
| 2.33.0.20250731 | [v2.33.0.20250731](https://github.com/aws/aws-for-fluent-bit/releases/tag/v2.33.0.20250731) | BUILD | Amazon Linux base container image version: 2.0.20250728.1 |
| 2.33.1 | [v2.33.1](https://github.com/aws/aws-for-fluent-bit/releases/tag/v2.33.1) | PATCH | Enhancement - Rework AL2 dockerfiles, Fix - Disable buildkit features |
| 3.0.0 | [v3.0.0](https://github.com/aws/aws-for-fluent-bit/releases) | MAJOR | Feature: AL2023 support, fluent-bit 4.x support

## Tags

* `latest`: The most recent version
* `Version number tag`: Each release has a version number, for example `2.33.0.20250731`, `2.33.1`
* `stable`: The most recent version that we have high confidence is stable for AWS use cases

> Note: The stable image tag continues to point to AWS for Fluent Bit version 2.x

### Additional Tags

* `debug-latest`: `latest` image with debug tooling[^3]
* `init-latest`: `latest` image using init process[^4]
* `init-debug-latest`: `init-latest` image with debug tooling[^3]

[^1]: https://aws.amazon.com/amazon-linux-2/faqs/
[^2]: https://www.cncf.io/blog/2025/04/25/fluent-bit-v4-0-celebrating-new-features-and-10th-anniversary/
[^3]: debug build, valgrind, core file uploading
[^4]: [init-process-for-fluent-bit](use_cases/init-process-for-fluent-bit/README.md)
