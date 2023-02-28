###  Integration Test for Init Process of Fluent Bit on ECS

Following this instruction, you will take the integration test for init process and get the test result



#### Requirements

1. [install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
2. [set up AWS account credential](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html)
3. [install AWS CDK](https://docs.aws.amazon.com/cdk/v2/guide/getting_started.html)



#### Deploy test resources

* Create some Fluent Bit config files locally  (you can use any config files that are valid, or [attached config files](config_files_for_test/)).

* Upload config files to S3 and get ARNs.

* Change the integ test CDK python stack to deploy your Fluent Bit init image or a specific tag. If you are testing a custom build, push your image to Amazon ECR. Reference the image you want to test in the stack: [integ_test_stack.py](https://github.com/aws/aws-for-fluent-bit/blob/mainline/integ/test_init/integ_test/integ_test/integ_test_stack.py#L41)

  **example:**

  ```python
        task_definition.add_container("log_router",
            # <<< replace with your custom build of init or a specific version >>>
            image=ecs.ContainerImage.from_registry("public.ecr.aws/aws-observability/aws-for-fluent-bit:init-latest"),
  ```

* Replace your ARNs in the `/integ_test/integ_test/integ_test_stack.py`: [integ_test_stack.py](https://github.com/aws/aws-for-fluent-bit/blob/mainline/integ/test_init/integ_test/integ_test/integ_test_stack.py#L11).

  **example:**

  ```python
  # change your ARNs here
  arn1 = "arn:aws:s3:::yourBucket/dummy-input.conf"
  arn2 = "arn:aws:s3:::yourBucket/dummy-filter.conf"
  arn3 = "arn:aws:s3:::yourBucket/dummy-parser.conf"
  arn4 = "arn:aws:s3:::yourBucket/dummy-s3-output.conf"
          
  
  environment={ 
              "aws_fluent_bit_init_s3_1": arn1,
              "aws_fluent_bit_init_s3_2": arn2,
              "aws_fluent_bit_init_s3_3": arn3,
              "aws_fluent_bit_init_s3_4": arn4,
              },
  ```
  
* Deploy the CDK project.

  ```shell
  cd WORKSPACE/aws-for-fluent-bit/integ/test_init/integ_test
  cdk synth
  cdk deploy IntegTestStack
  ```



#### Check the test result

* Go to ECS console to get cluster name and task-id we deployed.

* Use [ECS Exec](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html) to directly interact with container.
  ```shell
  # replace the cluster-name and task-id to yours
  
  aws ecs execute-command --cluster Cluster-name \
  --task task-id \
  --container log_router \
  --interactive \
  --command "/bin/sh"
  ```

* Check the result.

​		**example:**

```shell
# suppose we upload four config files to S3
dummy-input.conf
dummy-filter.conf
dummy-parser.conf
dummy-s3-output.conf

# 1. go to the fluent-bit-init-s3-files folder to check the result
cd /init/fluent-bit-init-s3-files
ls
# all config files you upload to S3 should be here, and the file content should be same


# 2. check the main fluent bit config file
cat /init/fluent-bit-init.conf
# the fluent bit config file content should include original fluent-bit.conf 
# and include all config files you upload to S3 except parser.conf
@INCLUDE /fluent-bit/etc/fluent-bit.conf
@INCLUDE /init/fluent-bit-init-s3-files/dummy-s3-output.conf
@INCLUDE /init/fluent-bit-init-s3-files/dummy-filter.conf
@INCLUDE /init/fluent-bit-init-s3-files/dummy-input.conf


# 3. check if the fluent bit command is modified successfully when the [parser] is used
cat /init/invoke_fluent_bit.sh
# check the last command line, it should add -R to specify the parser file:
exec /fluent-bit/bin/fluent-bit -e /fluent-bit/firehose.so -e /fluent-bit/cloudwatch.so -e /fluent-bit/kinesis.so -c /init/fluent-bit-init.conf -R /init/fluent-bit-init-s3-files/dummy-parser.conf
```



#### Destroy resources

* Destroy resources used for testing.
  ``` shell
  cdk destroy
  ```

