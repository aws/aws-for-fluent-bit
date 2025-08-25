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

## Version 3.0.0

With the upcoming release of AWS for Fluent Bit 3.0.0 we expect to introduce the following changes:
1. Migration from AL2 to AL2023
    - We are aware of the upcoming End of Life, EOL for AL2 on 2026-06-30[^1]
    - We want to take advantage of bare-bones AL2023 container images to reduce CVE risk we observed AL2 based AWS for Fluent Bit images
2. Migration from fluent-bit 1.9.10 to 4.x
    - We are aware of many changes our customers have been asking for from newer versions[^2]
    - We do not want to continue managing backports to 1.9.10 via [upstream-to-fluent-bit](https://github.com/amazon-contributing/upstream-to-fluent-bit)

## Version History

| Version | Release Notes | Bump | Reason |
|---------|---------------|------|--------|
| 2.32.5.20250626 | [v2.32.5.20250626](https://github.com/aws/aws-for-fluent-bit/releases/tag/v2.32.5.20250626) | BUILD | Amazon Linux base container image version: 2.0.20250623.0 |
| 2.33.0 | [v2.33.0](https://github.com/aws/aws-for-fluent-bit/releases/tag/v2.33.0) | MINOR | Feature: Add support for non-root user mode to the init image |
| 2.33.0.20250731 | [v2.33.0.20250731](https://github.com/aws/aws-for-fluent-bit/releases/tag/v2.33.0.20250731) | BUILD | Amazon Linux base container image version: 2.0.20250728.1 |
| 2.33.1 | [v2.33.1](https://github.com/aws/aws-for-fluent-bit/releases/tag/v2.33.1) | PATCH | Enhancement - Rework AL2 dockerfiles, Fix - Disable buildkit features |
| [Example]3.0.0 | [v3.0.0](https://github.com/aws/aws-for-fluent-bit/releases) | MAJOR | Feature: AL2023 support, fluent-bit 4.x support

## Tags

* `latest`: The most recent version
* `Version number tag`: Each release has a version number, for example `2.33.0.20250731`, `2.33.1`
* `stable`: The most recent version that we have high confidence is stable for AWS use cases

### Additional Tags

* `debug-latest`: `latest` image with debug tooling[^3]
* `init-latest`: `latest` image using init process[^4]
* `init-debug-latest`: `init-latest` image with debug tooling[^3]

[^1]: https://aws.amazon.com/amazon-linux-2/faqs/
[^2]: https://www.cncf.io/blog/2025/04/25/fluent-bit-v4-0-celebrating-new-features-and-10th-anniversary/
[^3]: debug build, valgrind, core file uploading
[^4]: [init-process-for-fluent-bit](use_cases/init-process-for-fluent-bit/README.md)
