import os
from aws_cdk import (
    aws_logs as logs,
    aws_autoscaling as autoscaling,
    aws_ec2 as ec2,
    aws_ecs as ecs,
    core,
)

# Create necessary ECS load testing resources - cloudwatch log group and ecs cluster 
class TestingResources(core.Stack):

    def __init__(self, scope: core.Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        log_group = logs.LogGroup(self, 'logGroup',
                                  removal_policy=core.RemovalPolicy.DESTROY)
 
        # Resources for ecs ec2 testing
        vpc = ec2.Vpc(
            self, "vpc",
            max_azs=2
        )
        vpc.apply_removal_policy(core.RemovalPolicy.DESTROY)

        asg = autoscaling.AutoScalingGroup(
            self, "fleet",
            instance_type=ec2.InstanceType("c5.24xlarge"),
            machine_image=ecs.EcsOptimizedImage.amazon_linux2(),
            associate_public_ip_address=True,
            desired_capacity=5,
            vpc=vpc,
            vpc_subnets={ 'subnet_type': ec2.SubnetType.PUBLIC },
        )
        asg.apply_removal_policy(core.RemovalPolicy.DESTROY)

        cluster = ecs.Cluster(
            self, 'ecsCluster',
            vpc=vpc
        )
        capacity_provider = ecs.AsgCapacityProvider(self, "asgCapacityProvider",
            auto_scaling_group=asg,
            enable_managed_termination_protection=True
        )
        cluster.add_asg_capacity_provider(capacity_provider)
        cluster.apply_removal_policy(core.RemovalPolicy.DESTROY)

        # Add stack outputs
        core.CfnOutput(self, 'CloudWatchLogGroupName', 
                       value=log_group.log_group_name, 
                       description='CloudWatch Log Group Name')
        
        core.CfnOutput(self, "ECSClusterName", 
                       value=cluster.cluster_name, 
                       description="ECS Cluster Name")

app = core.App()
TestingResources(app, os.environ['TESTING_RESOURCES_STACK_NAME'])
app.synth()
