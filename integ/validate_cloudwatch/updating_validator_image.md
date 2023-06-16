## CW Validator Image

The CW Validator image exists in our account as:

```
906394416424.dkr.ecr.us-west-2.amazonaws.com/cw-integ-validator:latest
```

If we need to perform a change or dependency update, build the image and push it to the account with that name. 

The image is set as an env var `CW_INTEG_VALIDATOR_IMAGE` in:
- Linux: buildspec_integ.yml
- Windows: integ/run-integ.ps1

The env var is used in `integ/test_cloudwatch/docker-compose.validate.yml`.
