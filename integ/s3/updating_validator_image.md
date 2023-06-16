## S3 Validator Image

The S3 Validator image exists in our account as:

```
906394416424.dkr.ecr.us-west-2.amazonaws.com/s3-integ-validator:arm64
906394416424.dkr.ecr.us-west-2.amazonaws.com/s3-integ-validator:x86_64
906394416424.dkr.ecr.us-west-2.amazonaws.com/s3-integ-validator-windows:x86_64
```

If we need to perform a change or dependency update, build the image and push it to the account with that name.

The base image URI is set as an env var `S3_INTEG_VALIDATOR_IMAGE` in:
- Linux: buildspec_integ.yml
- Windows: run-integ.ps1

The tag is the value of `${ARCHITECTURE}`

The env var is used in the `docker-compose.validate-and-clean.yml` files for firehose, kinesis, and S3 tests.
