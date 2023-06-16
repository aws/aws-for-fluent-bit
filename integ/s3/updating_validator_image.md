## S3 Validator Image

The S3 Validator image exists in our account for linux as:

```
906394416424.dkr.ecr.us-west-2.amazonaws.com/s3-integ-validator:arm64
906394416424.dkr.ecr.us-west-2.amazonaws.com/s3-integ-validator:x86_64
```

If we need to perform a change or dependency update, build the image and push it to the account with that name.

The base image URI is set as an env var `S3_INTEG_VALIDATOR_IMAGE` in:
- Linux: buildspec_integ.yml

The tag is the value of `${ARCHITECTURE}`

The env var is used in the `docker-compose.validate-and-clean.yml` files for firehose, kinesis, and S3 tests.

Storing the images in the account is more efficient than re-building them for each integration test execution. It ensures builds can not be blocked by external dependencies like pypi or go. 

For windows, we currently still build the images locally. This is partly because for windows, the base image changes with every monthly patch tuesday. The current windows base image is the largest part of the image, and is present on the AMI. Therefore, building it locally each test run can use that base without a large download. In addition, windows requires separate images for server version 2022 vs 2019 (and others if we support them in the future). The images are built in `run-integ.ps1`.
