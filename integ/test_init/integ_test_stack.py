from aws_cdk import (
    Stack,
    aws_autoscaling as autoscaling,
    aws_ec2 as ec2,
    aws_ecs as ecs,
    aws_iam as iam,
)
from constructs import Construct

# change your ARNs here
arn1 = "arn:aws:s3:::example/dummy-input.conf"
arn2 = "arn:aws:s3:::example/dummy-filter.conf"
arn3 = "arn:aws:s3:::example/dummy-parser.conf"
arn4 = "arn:aws:s3:::example/dummy-s3-output.conf"

class IntegTestStack(Stack):
    
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)
        
        vpc = ec2.Vpc(self, "VPC")
    
        cluster = ecs.Cluster(self, "Cluster", vpc=vpc)

        auto_scaling_group = autoscaling.AutoScalingGroup(self, "ASG", 
                vpc=vpc,
                instance_type=ec2.InstanceType("t2.micro"),   
                machine_image=ecs.EcsOptimizedImage.amazon_linux2(),
        )
        
        capacity_provider = ecs.AsgCapacityProvider(self, 
                "AsgCapacityProvider", 
                auto_scaling_group=auto_scaling_group
        )

        cluster.add_asg_capacity_provider(capacity_provider)

        task_definition = ecs.Ec2TaskDefinition(self, "TaskDef")

        task_definition.add_container("log_router",
            image=ecs.ContainerImage.from_registry("public.ecr.aws/aws-observability/aws-for-fluent-bit:init-latest"),
            memory_reservation_mib=50,
            logging=ecs.LogDrivers.aws_logs(
                stream_prefix="Firelens-log",
            ),
            environment={ 
            "aws_fluent_bit_init_s3_1": arn1,
            "aws_fluent_bit_init_s3_2": arn2,
            "aws_fluent_bit_init_s3_3": arn3,
            "aws_fluent_bit_init_s3_4": arn4,
            },
        )

        task_definition.task_role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("AmazonS3FullAccess")
        )

        task_definition.task_role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("AmazonSSMFullAccess")
        )

        task_definition.task_role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("CloudWatchFullAccess")
        )

        ecs_service = ecs.Ec2Service(self, "Service",
            cluster=cluster,
            task_definition=task_definition,
            enable_execute_command=True
        )