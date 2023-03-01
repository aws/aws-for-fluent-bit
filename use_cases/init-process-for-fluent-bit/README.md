# Init process for Fluent Bit on ECS, multi-config support



### What is init process and multi-config support?

Init process is the project we use to implement multi-config support. Multi-config support means you can use multiple config files conveniently to configure Fluent Bit on ECS. These config files can be your own config files that you upload to S3, or you can use the [built-in config files](https://github.com/aws/aws-for-fluent-bit/tree/mainline/ecs) we provide directly. 

When you want to use the multi-config feature, please choose our Fluent Bit images with `init` tag like `aws-for-fluent-bit:init-latest` or `aws-for-fluent-bit:init-2.27.0` which contains the init process. You can find our images on [Public ECR](https://gallery.ecr.aws/aws-observability/aws-for-fluent-bit) and [Docker Hub](https://hub.docker.com/r/amazon/aws-for-fluent-bit/tags).



### Why did we create the init process?

Currently, if you want to set up additional configs for Fluent Bit running on ECS, you need to [build a custom image](https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/config-file-type-file). And you cannot easily set up a [PARSER] section for Fluent Bit because using a parser in Fluent Bit requires you to specify the path of the parser file under the [SERVICE] section. With the init process for Fluent Bit, these import statements are not needed, init process will automatically add them.

Init process is designed to solve above mentioned problems and improve user experience of using Fluent Bit on ECS. You only need to set the ARN or path of the config file in the ECS Task Definition, without telling us if it is a parser file or normal config file. Init process will process each config file, use [@INCLUDE](https://docs.fluentbit.io/manual/administration/configuring-fluent-bit/classic-mode/configuration-file#config_include_file-1) keyword to add them to the main config file, and change the Fluent Bit command if the parser is used.

The init process also injects ECS Task Metadata into the Fluent Bit container as environment variables, so you can use them in the Fluent Bit config.



### How to use multi-config feature?

1. Use `aws-for-fluent-bit` images with `init` tag.

2. Specify config files as environment variable in the FireLens configuration Environment setting.

   **Example:**

   ```
   "environment": [
                   {
                       "name": "aws_fluent_bit_init_s3_1",
                       "value": "arn:aws:s3:::yourBucket/aaaaa.conf"
                   },
                   {
                       "name": "aws_fluent_bit_init_s3_2",
                       "value": "arn:aws:s3:::yourBucket/bbbbb.conf"
                   },
                   {
                       "name": "aws_fluent_bit_init_file_1",
                       "value": "/ecs/s3.conf"
                   }
               ]
   ```

   **We support two kinds of config files:**

   * Config files which stored in your S3 bucket
     You need to set the name of the env var using prefix `aws_fluent_bit_init_s3_`, the number after this prefix cannot be repeated, and set the `ARN` of your config file as the value of the env var.

   * Config files which from the image

     * Use [our built-in config files](https://github.com/aws/aws-for-fluent-bit/tree/mainline/ecs)
     
       You need to set the name of the env var using prefix `aws_fluent_bit_init_file_`, the number after this prefix cannot be repeated, and set the `Path` of your config file inside the image as the value of the env var.
     
     * Build a custom image
     
       You can build a custom image using image with `init` tag as the base and add your own configs. Set the name of the env var using prefix `aws_fluent_bit_init_file_`, the number after this prefix cannot be repeated, and set the `Path` of your own config file inside the image as the value of the env var. You can also specify a parser config directly without to do anything additional, just like the two uses above.
       
       **Example:**
       
       Dockerfile
       
       ```
       FROM public.ecr.aws/aws-observability/aws-for-fluent-bit:init-latest
       ADD your-filter.conf  /your-filter.conf
       ADD your-parser.conf  /your-parser.conf
       ADD your-output.conf  /your-output.conf
       ```
       
       FireLens configuration
       
       ```
       "environment": [
                       {
                           "name": "aws_fluent_bit_init_file_1",
                           "value": "/your-filter.conf"
                       },
                       {
                           "name": "aws_fluent_bit_init_file_2",
                           "value": "/your-parser.conf"
                       },
                       {
                           "name": "aws_fluent_bit_init_file_3",
                           "value": "/your-output.conf"
                       }
                   ]
       ```
       
       
     

3. Set up your ECS Task role

   If you specify the config file from your S3 bucket, the init process will download it from your bucket. So please add the following permissions: 

   ``` 
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": [
                   "s3:GetObject",
                   "s3:GetBucketLocation"
               ],
               "Resource": "*"
           }
       ]
   }
   ```

​		**Note:** [IAM roles for tasks](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html) is different with [ECS task execution role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html). 
​		If you are not familiar with them, please check out more details.



### How to use ECS Task Metadata in Fluent Bit config?

The init process injects ECS Task Metadata into the Fluent Bit container as environment variables:

```
AWS_REGION / AWS_AVAILABILITY_ZONE / ECS_LAUNCH_TYPE / ECS_CLUSTER
ECS_FAMILY / ECS_TASK_ARN / ECS_TASK_ID / ECS_REVISION / ECS_TASK_DEFINITION
```

You can use them as env vars directly in the Fluent Bit config.

**Example:**

```
[OUTPUT]
    Name   		cloudwatch_logs
    Match  		*
    region 		${AWS_REGION}
```



### How init process works?

1. The init process will request [ECS Task Metadata](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-metadata-endpoint-v4.html). Get valuable parts from the responses and set them using `export` as environment variables.

2. After you set the ARN or Path of the config files as environment variables in the ECS Task Definition, the init process will collect all config files which you specified (download files which come from S3 if needed).

3. The init process will create the main config file and use @INCLUDE keyword to add the config file FireLens generated into it.

4. The init process will process these config files one by one, use @INCLUDE keyword to add config files to the main config file. And the init process will check if each config file is a parser config. If it is a parser config, change the original Fluent Bit command, add -R to specify that parser. For more details, please see the example below.

5. The init process will finally invoke Fluent Bit with the modified main configuration file.



**Example:**

Suppose you specify config files as environment variable in the FireLens configuration as:

```
"environment": [
                {
                    "name": "aws_fluent_bit_init_s3_1",
                    "value": "arn:aws:s3:::yourBucket/your-filter.conf"
                },
                {
                    "name": "aws_fluent_bit_init_s3_2",
                    "value": "arn:aws:s3:::yourBucket/your-parser.conf"
                },
                {
                    "name": "aws_fluent_bit_init_s3_3",
                    "value": "arn:aws:s3:::yourBucket/your-s3-output.conf"
                }
            ]
```

**your-filter.conf** (new config you created and init process downloaded from S3, path inside the image:`/init/fluent-bit-init-s3-files/your-filter.conf`)

```
[FILTER]
    Name          parser
    Match         *
    Key_Name      data
    Parser        example
```

**your-parser.conf** (new config you created and init process downloaded from S3, path inside the image:`/init/fluent-bit-init-s3-files/your-parser.conf`)

```
[PARSER]
    Name          example
    Format        regex
    Regex         ^(?<INT>[^ ]+) (?<FLOAT>[^ ]+) (?<BOOL>[^ ]+) (?<STRING>.+)$
```

**your-s3-output.conf** (new config you created and init process downloaded from S3, path inside the image:`/init/fluent-bit-init-s3-files/your-s3-output.conf`)

```
[OUTPUT]
    Name                  s3
    Match                 *
    bucket                your-result
    region                ${AWS_REGION}
    total_file_size       1M
    upload_timeout        1m
    use_put_object        On
```

**fluent-bit.conf** ([original main config file FireLens generated](https://aws.amazon.com/blogs/containers/under-the-hood-firelens-for-amazon-ecs-tasks/), path inside the image: `/fluent-bit/etc/fluent-bit.conf`)

```
[INPUT]
    Name             forward
    unix_path        /var/run/fluent.sock

.
.
.


[OUTPUT]
    Name                    cloudwatch
    Match                   app-firelens*
    auto_create_group       true
    log_group_name          /aws/ecs/containerinsights/$(ecs_cluster)/application
    log_stream_name         $(ecs_task_id)
    region                  us-west-2
    retry_limit             2
```



**You don't need to set @INCLUDE or specify the path of the parser file under the [SERVICE] section, don't need to modify the Fluent Bit command, and don't need to tell us if there is a parser config.**

**The init process will download config files you specified in Task Definition from S3, and check if each config file is a parser config. If it's not a parser config, the init process will use @INCLUDE keyword to add this config to the main config file. If it's a parser config, the init process will change the original Fluent Bit command, add -R to specify that parser config.** 



**After init process has processed:**

**fluent-bit-init.conf** (new main config file generated by init process, will used to invoke Fluent Bit, path inside the image:`/init/fluent-bit-init.conf`)

```
@INCLUDE /fluent-bit/etc/fluent-bit.conf
@INCLUDE /init/fluent-bit-init-s3-files/your-filter.conf
@INCLUDE /init/fluent-bit-init-s3-files/your-s3-output.conf
```

Original command to invoke Fluent Bit:

```
/fluent-bit/bin/fluent-bit -e /fluent-bit/firehose.so 
-e /fluent-bit/cloudwatch.so -e /fluent-bit/kinesis.so 
-c /fluent-bit/etc/fluent-bit.conf
```

Modified command to invoke Fluent Bit (change the main config file to `fluent-bit-init.conf`, add -R to specify the parser):

```
/fluent-bit/bin/fluent-bit -e /fluent-bit/firehose.so 
-e /fluent-bit/cloudwatch.so -e /fluent-bit/kinesis.so 
-c /init/fluent-bit-init.conf
-R /init/fluent-bit-init-s3-files/your-parser.conf
```