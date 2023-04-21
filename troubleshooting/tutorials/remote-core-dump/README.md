# Tutorial: Obtaining a Core Dump from a live Fluent Bit process

## Introduction

This tutorial will show you how to debug a crashed or frozen Fluent Bit using gdb. 

You can use this tutorial for local, ECS EC2, EKS EC2, and ECS Fargate debugging. The tutorial contains versions of step 2 for each platform.

Once you have setup the debug build of Fluent Bit on your platform, you have two options. For a live Fluent Bit, you can follow [Step 3: Using GDB with a live Fluent Bit](#step-3-using-gdb-with-a-live-fluent-bit) to dump the current state of the process. If Fluent Bit is crashing, then you want to set up the debug build and wait for it to crash. Once it does, you will have a core file and can follow [Step 4: Using GDB with a core file (crashed Fluent Bit)](#step-4-using-gdb-with-a-core-file-crashed-fluent-bit) to obtain information about the call stack at the time of the crash. You can use that information to fix the issue yourself or upload it to a GitHub issue so that we can fix it. 


- [Step 1: Debug Build of Fluent Bit](#step-1-debug-build-of-fluent-bit)
- [Step 2: Create an S3 Bucket to send crash symbols to (Only needed for crash uploads to S3)](##step-2-create-an-s3-bucket-to-send-crash-symbols-to-only-needed-for-crash-uploads-to-s3)
- [Step 3: Modifying your deployment to capture a core file](#step-3-modifying-your-deployment-to-capture-a-core-file)
    - [Setup for Local Dev Machine or Instance](#setup-for-local-dev-machine-or-instance)
    - [Setup for ECS EC2](#setup-for-ecs-ec2)
    - [Setup for ECS Fargate](#setup-for-ecs-fargate)
    - [Setup for EKS EC2](#setup-for-eks-ec2)
- [Step 4: Using GDB with a live Fluent Bit](#step-4-using-gdb-with-a-live-fluent-bit)
- [Step 5: Using GDB with a core file (crashed Fluent Bit)](#step-5-using-gdb-with-a-core-file-crashed-fluent-bit)


## Step 1: Debug Build of Fluent Bit

Clone the AWS for Fluent Bit source code, and run `make debug` for a plain debug image, or `make init-debug` for an init debug image. The resulting images will be tagged `amazon/aws-for-fluent-bit:debug` and `amazon/aws-for-fluent-bit:init-debug`.

When Fluent Bit crashes, a zipped core file, stacktrace, and the Fluent Bit executable will be output to the `/cores` directory and the files will also be uploaded to S3.

There are couple of things to note about the debug target for the core file debugging use case:
- The Fluent Bit upstream base version is specified with `ENV FLB_VERSION`
- Fluent Bit is compiled with CMake flag `-DFLB_DEBUG=On`
- `gdb` is installed in the final stage of the Docker build.
- `aws` cli is installed to copy files to the S3 bucket.

When you clone AWS for Fluent Bit, you will automatically get the latest Dockerfile for our latest release on the mainline branch. To create a debug build of a different version, either check out the tag for that version, or modify the `ENV FLB_VERSION` at the top of the `/scripts/dockerfiles/Dockerfile.build` to install the desired Fluent Bit base version.

Once you are ready, build the debug image:

```
make debug
```
The resulting image will be tagged `amazon/aws-for-fluent-bit:debug`

And then push this image to a container image repository such as Amazon ECR so that you can use it in your deployment in the next step.

#### Custom Entrypoints
Please note that if you are customizing your aws-for-fluent-bit debug image with a custom entrypoint.sh, you need to add the following as the last line of your entrypoint.sh:
```
echo "AWS for Fluent Bit Container Image Version `cat /AWS_FOR_FLUENT_BIT_VERSION` - Debug Image with S3 Core Uploader"; \
    if [ "$S3_BUCKET" == "" ]; then \
        echo "Note: Please set S3_BUCKET environment variable to your crash symbol upload destination S3 bucket"; \
    fi; \
    if [ "$S3_KEY_PREFIX" == "issue" ]; then \
        echo "Note: Please set S3_KEY_PREFIX environment variable to a useful identifier - e.g. company name, team name, customer name"; \
    fi; \
    export RANDOM_ID_VALUE=$(($RANDOM%99999))$(($RANDOM%99999))$(($RANDOM%99999)); \
    echo "RANDOM_ID is set to $RANDOM_ID_VALUE"; \
    /fluent-bit/bin/fluent-bit -c /fluent-bit/etc/fluent-bit.conf; \
    /core_uploader.sh $S3_BUCKET $S3_KEY_PREFIX
```

If the following command exists in your entrypoint.sh file, remove it:
```
exec /fluent-bit/bin/fluent-bit -e /fluent-bit/firehose.so -e /fluent-bit/cloudwatch.so -e /fluent-bit/kinesis.so -c /fluent-bit/etc/fluent-bit.conf
```

#### Crash Symbol Description
The following crash symbols are output by the debug image:

- .core.zip: A zipped core file
- .stacktrace: a stack trace file from the core dump
- .executable: the Fluent Bit executable that crashed

All crash files are prefixed with:
```
<$S3_KEY_PREFIX>_<date in format"%FT%H%M%S>_<hostname>_<RUN_ID>.core.zip
```

These files are output to the /cores directory which can be mounted to with Docker volumes, or optionally sent to an S3 bucket. See how to configure your S3 bucket in step 2.


## Step 2: Create an S3 Bucket to send crash symbols to (Only needed for crash uploads to S3)

#### Bucket Setup
1. In AWS S3 console, choose **Create bucket**.
2. For **bucket name** enter a name (for example, my-aws-for-fluent-bit-crash-symbols)
3. Choose **Create bucket**

#### IAM Update for S3 Access
For the IAM role or user which is used by aws-for-fluent-bit provide access to the created bucket with the following s3 policy:

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "s3:PutObject",
            "s3:GetObject",
            "s3:DeleteObject"
        ],
        "Resource": ["arn:aws:s3:::<my_bucket>"]
    }
  ]
}
```

#### Sending crash symbols to an S3 bucket
Set the following environment variables on your debug image to send crash symbols to your S3 bucket

    a. `S3_BUCKET` => an S3 bucket that your task can upload too. 
    b. `S3_KEY_PREFIX` => this is the key prefix in S3 for the core dump, set it to something useful like the ticket ID or a human readable string. It must be valid for an S3 key.

## Step 3: Modifying your deployment to capture a core file

Follow the version of this step that fits your deployment mode. 

- [Setup for Local Dev Machine or Instance](#setup-for-local-dev-machine-or-instance)
- [Setup for ECS EC2](#setup-for-ecs-ec2)
- [Setup for ECS Fargate](#setup-for-ecs-fargate)
- [Setup for EKS EC2](#setup-for-eks-ec2)

### Setup for Local Dev Machine or Instance

#### Obtain crash symbols via a mounted volume
Simply run the debug build of Fluent Bit with ulimit unlimited and with the `/cores` directory mounted onto your host:
```
docker run --ulimit core=-1 -v /somehostpath:/cores -v $(pwd):/fluent-bit/etc amazon/aws-for-fluent-bit:debug
```

The command mounts the current working directory to `/fluent-bit/etc` which is the default directory for the main `fluent-bit.conf` config file- this assumes you have a config file in your current working directory.

You may need to customize the Docker run command to mount additional files or your AWS credentials. This is just an example. In some cases your system may require the following additional arguments to create core files:

```
--cap-add=SYS_PTRACE --security-opt seccomp=unconfined
```

When the Fluent Bit debug image crashes, a core file should be outputted to `/somehostpath`. When that happens, proceed to [Step 4: Using GDB with a core file (crashed Fluent Bit)](#step-4-using-gdb-with-a-core-file-crashed-fluent-bit).  Alternatively, you can use `docker exec` to get a terminal into the container and follow [Step 3: Using GDB with a live Fluent Bit](#step-3-using-gdb-with-a-live-fluent-bit).

#### Obtain crash symbols via S3 bucket
You can also send crash symbols to an S3 bucket when Fluent Bit crashes.
Again, simply run the debug build of Fluent Bit with ulimit unlimited and with the `/cores` directory mounted onto your host, along with environment variable references to your S3 bucket.
```
docker run --ulimit core=-1 \
    -v /somehostpath:/cores \
    -v $(pwd):/fluent-bit/etc \
	--env S3_BUCKET=<my_s3_bucket>  \
	--env S3_KEY_PREFIX=<my_s3_key_prefix> \
    amazon/aws-for-fluent-bit:debug
```
We recommend choosing an s3_key_prefix that is related to your company, team, or group's name.

### Setup for ECS EC2

#### Obtain crash symbols via a mounted volume
You will need to modify your existing Task Definition or CloudFormation or CDK or etc to include the following:

1. A volume for the `/cores` directory in Fluent Bit that is mounted onto the host file system. This is necessary because when the core dump is produced, we need to save it somewhere, since containers are ephemeral. 
2. Set `initProcessEnabled` in the task definition so that when Fluent Bit crashes or is killed, orphaned processes will be cleaned up gracefully. 
3. Grant the `SYS_PTRACE` capability to the Fluent Bit container so that we can attach to it with a debugger. 
4. Enable unlimited core ulimit. This ensures there is no limit on the size of the core file. 
4. [Optional] Grant the Task Role ECS Exec permissions. This is necessary if you are debugging a Fluent Bit task that is still running and is frozen or misbehaving. You can use ECS Exec and `gdb` to attach the the live Fluent Bit process. 

There is an example task definition in this directory named `ecs-ec2-task-def.json` which you can use as a reference. 

#### Volume Mount for /cores directory

Define a volume mount for the Fluent Bit container like this:

```
            "mountPoints": [{
                "containerPath": "/cores",
                "sourceVolume": "core-dump"
            }],
```

Then, you can define the volume in the task definition to be a path on your EC2 host:

```
    "volumes": [{
        "name": "core-dump",
        "host" : {
            "sourcePath" : "/var/fluentbit/cores"
        },
    }],
```

When Fluent Bit crashes, it will output a core dump to this directory. You can then SSH into your EC2 instance and read/obtain the core file in the `/var/fluentbit/cores` directory.

#### Set initProcessEnabled and enable SYS_PTRACE capability

The flag `initProcessEnabled` ensures that when Fluent Bit crashes or is killed, orphaned processes will be cleaned up gracefully. This is primarily important if you are enabling ECS Exec, as it ensures the embedded SSM Agent and shell session are cleaned up gracefully if/when you terminate Fluent Bit. 

The `SYS_PTRACE` capability allows a debugging like gdb to attach to the Fluent Bit process. 

Here is an example task definition JSON snippet:
```
            "linuxParameters": {
                            "initProcessEnabled": true,
                            "capabilities": {
                            "add": [
                                    "SYS_PTRACE"
                                ]
                            }
             }
        },
```

#### Set unlimited core ulimit

You can add this to your container definition for the Fluent Bit container:

```
"ulimits": [
                {
                    "hardLimit": -1,
                    "softLimit": -1,
                    "name": "core"
                }
            ]
```

This ensures the core dump can be as large as is needed to capture all state/debug information. This may not be needed, but its ideal to set it just in case.

#### [Optional] Enable ECS Exec

If you are debugging a live Fluent Bit task, this is necessary. 

We recommend following the [ECS Exec tutorial](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html) in the Amazon ECS developer documentation.

The tutorial explains how to:

1. Grant the task role permissions for ECS Exec. 
2. Launch a task with ECS Exec. You must enable ECS Exec in the AWS API when you launch a task in order to exec into it later. 
3. Exec into your task once it is running and obtain a shell session. Once you have done this you can proceed to [Step 3: Using GDB with a live Fluent Bit](#step-3-using-gdb-with-a-live-fluent-bit).

#### Obtain crash symbols via S3 Bucket
Ensure that your task role arn has access to the S3 bucket created in step 2, and set `S3_BUCKET` and `S3_KEY_PREFIX` environment variables in your ECS Task definition. Here's an example task definition environment variable configuration:

```
{
   ...
    "containerDefinitions": [
      {
        ...
        "environment": [
          ...
          {
            "name": "S3_BUCKET",
            "value": "<my_s3_bucket>"
          },
          {
            "name": "S3_KEY_PREFIX",
            "value": "<my_s3_key_prefix>"
          }
        ],
      },
    ]
}
```
Upon crashing, symbols will be uploaded to S3.


### Setup for ECS Fargate

#### Obtain crash symbols via a mounted volume
You will need to modify your existing Task Definition or CloudFormation or CDK or etc to include the following:

1. A volume for the `/cores` directory in Fluent Bit that is attached to an EFS file system. This is necessary because when the core dump is produced, we need to save it somewhere, and Fargate is a serverless platform. Thus, we use EFS for persistent storage. 
2. Set `initProcessEnabled` in the task definition so that when Fluent Bit crashes or is killed, orphaned processes will be cleaned up gracefully. 
3. Grant the `SYS_PTRACE` capability to the Fluent Bit container so that we can attach to it with a debugger. 
4. [Optional] Grant the Task Role ECS Exec permissions. This is necessary if you are debugging a Fluent Bit task that is still running and is frozen or misbehaving. You can use ECS Exec and gdb to attach the the live Fluent Bit process. 

There is an example task definition in this directory named `ecs-fargate-task-def.json` which you can use as a reference. 

#### Create EFS Filesystem

We recommend following this tutorial to create your EFS filesystem and an EC2 instance that mounts the filesystem:

1. [Create an EFS File System](https://docs.aws.amazon.com/efs/latest/ug/gs-step-two-create-efs-resources.html)
2. [Mount the EFS File System to an EC2 Instance so you can ssh into the instance and access files on the EFS](https://docs.aws.amazon.com/efs/latest/ug/gs-step-one-create-ec2-resources.html)

#### Volume Mount for /cores directory

Define a volume mount for the Fluent Bit container like this:

```
            "mountPoints": [{
                "containerPath": "/cores",
                "sourceVolume": "core-dump"
            }],
```

Then, you can define the volume in the task definition to be your EFS filesystem:

```
    "volumes": [{
        "name": "core-dump",
        "efsVolumeConfiguration": 
             { 
                 "fileSystemId": "fs-1111111111111111111" 
             }
    }],
```

As a sanity check that you setup the EFS filesystem correctly on the Fargate task, create a file in the EFS filesystem. For example, `touch my-efs-id.txt`. Then, when you later setup your Fargate task, you can use ECS Exec to check that you can see the file in the cores directory: `ls /cores`. 

#### Set initProcessEnabled and enable SYS_PTRACE capability

The flag `initProcessEnabled` ensures that when Fluent Bit crashes or is killed, orphaned processes will be cleaned up gracefully. This is primarily important if you are enabling ECS Exec, as it ensures the embedded SSM Agent and shell session are cleaned up gracefully if/when you terminate Fluent Bit. 

The `SYS_PTRACE` capability allows a debugging like gdb to attach to the Fluent Bit process. 

Here is an example task definition JSON snippet:
```
            "linuxParameters": {
                            "initProcessEnabled": true,
                            "capabilities": {
                            "add": [
                                    "SYS_PTRACE"
                                ]
                            }
             }
        },
```

#### [Optional] Enable ECS Exec

If you are debugging a live Fluent Bit task, this is necessary. 

We recommend following the [ECS Exec tutorial](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html) in the Amazon ECS developer documentation.

The tutorial explains how to:

1. Grant the task role permissions for ECS Exec. 
2. Launch a task with ECS Exec. You must enable ECS Exec in the AWS API when you launch a task in order to exec into it later. 
3. Exec into your task once it is running and obtain a shell session. Once you have done this you can proceed to [Step 3: Using GDB with a live Fluent Bit](#step-3-using-gdb-with-a-live-fluent-bit).

#### Obtain crash symbols via S3 Bucket
Ensure that your task role arn has access to the S3 bucket created in step 2, and set `S3_BUCKET` and `S3_KEY_PREFIX` environment variables in your ECS Task definition. Here's an example task definition environment variable configuration:

```
{
   ...
    "containerDefinitions": [
      {
        ...
        "environment": [
          ...
          {
            "name": "S3_BUCKET",
            "value": "<my_s3_bucket>"
          },
          {
            "name": "S3_KEY_PREFIX",
            "value": "<my_s3_key_prefix>"
          }
        ],
      },
    ]
}
```

Upon crashing, symbols will be uploaded to S3.

### Setup for EKS EC2

If you are running the container in EKS/Kubernetes, then you can not set ulimits at container launch time. This must be set in the Docker systemd unit settings in `/usr/lib/systemd/system/docker.service`. Check that this file has `LimitCORE=infinity` under the `[Service]` section. 

In Kubernetes, you will also still need to make sure the `/cores` directory in Fluent Bit is mounted to some host path to ensure any generated core dump is saved permanently. 

The changes to your deployment yaml might be include the following:
```
        image: 111111111111.dkr.ecr.us-west-2.amazonaws.com/core-file-build:latest
...
        volumeMounts:
        - name: coredump
          mountPath: /cores/
          readOnly: false
...
      volumes:
      - name: coredump
        hostPath:
          path: /var/fluent-bit/core
```

If/when Fluent Bit crashes, you should get a core dump file in the `/var/fluent-bit/core` directory on your EKS EC2 node. You can then SSH into the node and read/copy the core file. 

Proceed through the next steps to understand how to use `gdb`.

## Step 3: Using GDB with a live Fluent Bit

If Fluent Bit is still running, you can attach a debugger to it to gain information about its state. Please note, that this technique may have very limited usefulness in many scenarios. AWS for Fluent Bit team engineers historically have exclusively used the techniques in [Step 4: Using GDB with a core file (crashed Fluent Bit)](#step-4-using-gdb-with-a-core-file-crashed-fluent-bit).

The reason is that in most cases, bug reports are for a crashed Fluent Bit. In that case, we need to know the state of the program during the crash. And the only way to obtain that is to wait for it to crash and then examine the core file that was produced. 

In the shell session obtained via `docker exec` or ECS Exec, get the PID of the Fluent Bit process:

```
ps -e
```

If you set `initProcessEnabled`, then you will see that Fluent Bit is not PID 0. If you did not set `initProcessEnabled`, then Fluent Bit should be PID 0.

Next, move into the `/cores` directory. This is necessary because when we use GDB to force the running process to output a core file it will by default be outputted to the current working directory. The `cores` directory should be mounted onto your host/EFS filesystem- so you can access/copy the core file later.

```
cd /cores
```

Finally, attach to Fluent Bit with GDB:

```
gdb -p {Fluent Bit PID}
```

And then you can use GDB to generate a core file showing the current state of execution. This will not terminate Fluent Bit:

```
generate-core-file
```

You can also run other GDB commands. Follow the next step to understand how to read the core file. 

## Step 4: Using GDB with a core file (crashed Fluent Bit)

First, you will need to obtain the compiled Fluent Bit debug binary, for use with GDB. The easiest way to do this is to pull it out of the debug container image you created in Step 1. You must use the exact same binary as produced the core file.

The following commands will copy the binary to your local directory:

```
docker create -ti --name tmp amazon/aws-for-fluent-bit:latest
docker cp tmp:/fluent-bit/bin/fluent-bit .
docker stop tmp
docker rm tmp
```

Next, invoke GDB with the core file and the binary:

```
gdb <binary-file> <core-dump-file>
```

Once inside of gdb, the following commands will be useful:
- `bt`: backtrace, see the state of the stack
- `thread apply all bt full`: page through the output to see the full backtrace for all threads
- `list`: See the code around the current line

These are the commands that our team typically uses to pull information out of a core file. Once you know the state of the stack in each thread, you can cross reference this with the code and generally determine what caused the crash.

For a full reference for GDB, see its [man page](https://linux.die.net/man/1/gdb).

You may get a note from GDB on startup that it is missing debuginfo:

```
Missing separate debuginfos, use: debuginfo-install bzip2-libs-1.0.6-13.amzn2.0.3.x86_64 cyrus-sasl-lib-2.1.26-24.amzn2.x86_64 elfutils-libelf-0.176-2.amzn2.x86_64 elfutils-libs-0.176-2.amzn2.x86_64
```

You can install these with [`debuginfo-install`](https://man7.org/linux/man-pages/man1/debuginfo-install.1.html) which can be obtained with [`yum-utils`](https://man7.org/linux/man-pages/man1/yum-utils.1.html).

1. Get `debuginfo-install`
```
sudo yum update && sudo yum install yum-utils
```

2. Then run the command provided by GDB to install debug info:
```
sudo debuginfo-install bzip2-libs-1.0.6-13.amzn2.0.3.x86_64 cyrus-sasl-lib-2.1.26-24.amzn2.x86_64 elfutils-libelf-0.176-2.amzn2.x86_64 elfutils-libs-0.176-2.amzn2.x86_64
```
