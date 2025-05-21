## ⚠️Experimental Build⚠️ - Not meant for public consumption

This experimental build is designed to allow early-adopters the option to test an unverified, unstable version on aws-for-fluent-bit. Experimental build will only cover building and publishing images to a private ECR repository.

### Requirements

1. AWS Account with ECR repository that will host created images
2. [awscli v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
3. Docker or container runtime equivalent that can run `docker build/tag` commands for linux containers
4. Choose a tag or branch from fluent-bit repository to target a experimental build
   - Branches - https://github.com/fluent/fluent-bit/branches (Ex: 3.2, master)
   - Tags - https://github.com/fluent/fluent-bit/tags (Ex: v3.2.10, v4.0.2)

### Steps

1. Checkout `experimental` branch - `git switch -c experimental`
2. Set environment variable `FLB_TAG` via `export FLB_TAG=v3.2.10` to target the [v3.2.10](https://github.com/fluent/fluent-bit/tree/v3.2.10) Tag (replace with desired branch/tag)
3. Run `make release` (may take some time to compile CMake3/fluent-bit)
4. Run `docker image ls amazon/aws-for-fluent-bit` to check for images
5. [optional] Validate container via `docker run -it amazon/aws-for-fluent-bit /bin/bash`
   - If container enters it should be /bin/bash shell
   - Can run `cat /fluent-bit/EXPERIMENTAL_VERSION` to validate tag/branch used
   - Can run fluent-bit via `./fluent-bit/bin/fluent-bit`
6. [optional] [Creating an Amazon ECR private repository to store images](https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html)
7. [Login to ECR private repository](https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html#registry-auth-token)
8. [Pushing a Docker image to an Amazon ECR private repository](https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html) from result of Step #3

#### Step 3 Example Output

```
docker image ls amazon/aws-for-fluent-bit
REPOSITORY                  TAG            IMAGE ID       CREATED          SIZE
amazon/aws-for-fluent-bit   init-latest    2619aa77cca8   4 minutes ago    403MB
amazon/aws-for-fluent-bit   latest         fd3b71b19f15   4 minutes ago    387MB
amazon/aws-for-fluent-bit   main-release   fd3b71b19f15   4 minutes ago    387MB
amazon/aws-for-fluent-bit   build-init     70b7232f4918   8 minutes ago    1.92GB
amazon/aws-for-fluent-bit   build          f827ae9bc616   10 minutes ago   3.46GB
```

#### Step 5.c Example Output

```
bash-4.2# ./fluent-bit/bin/fluent-bit 
Fluent Bit v3.2.10
* Copyright (C) 2015-2025 The Fluent Bit Authors
* Fluent Bit is a CNCF sub-project under the umbrella of Fluentd
* https://fluentbit.io

______ _                  _    ______ _ _           _____  _____ 
|  ___| |                | |   | ___ (_) |         |____ |/ __  \
| |_  | |_   _  ___ _ __ | |_  | |_/ /_| |_  __   __   / /`' / /'
|  _| | | | | |/ _ \ '_ \| __| | ___ \ | __| \ \ / /   \ \  / /  
| |   | | |_| |  __/ | | | |_  | |_/ / | |_   \ V /.___/ /./ /___
\_|   |_|\__,_|\___|_| |_|\__| \____/|_|\__|   \_/ \____(_)_____/


[2025/05/21 22:15:03] [ info] [fluent bit] version=3.2.10, commit=a988291a19, pid=8
[2025/05/21 22:15:03] [ info] [storage] ver=1.5.2, type=memory, sync=normal, checksum=off, max_chunks_up=128
[2025/05/21 22:15:03] [ info] [simd    ] disabled
[2025/05/21 22:15:03] [ info] [cmetrics] version=0.9.9
[2025/05/21 22:15:03] [ info] [ctraces ] version=0.6.1
[2025/05/21 22:15:03] [ info] [sp] stream processor started
```

### FAQ

1. Is this image AWS supported / issues tracked? - Not currently, use at your own discretion
2. Does this include upstream fixes/cherry-picks from https://github.com/amazon-contributing/upstream-to-fluent-bit? - No, only a few cherry-picks are not currently part of fluent-bit
   - [adds entity to PLE calls in cloudwatch logs plugin when used in EKS with kubernetes filter](https://github.com/amazon-contributing/upstream-to-fluent-bit/pull/2)
   - [out_cloudwatch: add account ID support for CloudWatch entity](https://github.com/amazon-contributing/upstream-to-fluent-bit/pull/4)
3. Why isn't the base image updated to AL2023? - Needs more time
4. Will there be updates to this build process? - Likely not