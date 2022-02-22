import os
import json
from aws_cdk import (
    aws_s3 as s3,
    aws_kinesis as kinesis,
    aws_kinesisfirehose as firehose,
    aws_iam as iam,
    core,
)

THROUGHPUT_LIST = json.loads(os.environ['THROUGHPUT_LIST'])
PLATFORM = os.environ['PLATFORM'].lower()
PREFIX= os.environ['PREFIX']

# Create necessary testing resources - s3 bucket, data streams and delivery streams
class LogStorage(core.Stack):

    def __init__(self, scope: core.Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        bucket = s3.Bucket(self, 's3Bucket',
                           versioned=True,
                           removal_policy=core.RemovalPolicy.DESTROY,
                           auto_delete_objects=True)
        
        firehose_role = iam.Role(self, 'firehoseRole', assumed_by=iam.ServicePrincipal('firehose.amazonaws.com'))
        iam.Policy(self, 's3Policy', policy_name='s3-permission-for-firehose',
                   statements=[iam.PolicyStatement(actions=['s3:*'], resources=['arn:aws:s3:::' + bucket.bucket_name + '/*'])],
                   roles=[firehose_role],
        )

        names = locals()
        for throughput in THROUGHPUT_LIST:
            # Data streams and related delivery streams for kinesis test
            names[PLATFORM+'_kinesis_stream_'+throughput] = kinesis.Stream(self, PLATFORM+'KinesisStream'+throughput,
                                                                           stream_name=PREFIX+PLATFORM+'-kinesisStream-'+throughput,
                                                                           shard_count=100)
            kinesis_policy = iam.Policy(self, 'kinesisPolicyfor'+throughput,
                                        statements=[iam.PolicyStatement(actions=['kinesis:*'], resources=[names.get(PLATFORM+'_kinesis_stream_'+throughput).stream_arn])],
                                        roles=[firehose_role],
            )
            names[PLATFORM+'_kinesis_test_delivery_stream_'+throughput] = firehose.CfnDeliveryStream(
                                                                          self, PLATFORM+'KinesisTestDeliveryStream'+throughput,
                                                                          delivery_stream_name=PREFIX+PLATFORM+'-kinesisTest-deliveryStream-'+throughput,
                                                                          delivery_stream_type='KinesisStreamAsSource',
                                                                          kinesis_stream_source_configuration=firehose.CfnDeliveryStream.KinesisStreamSourceConfigurationProperty(
                                                                            kinesis_stream_arn=names.get(PLATFORM+'_kinesis_stream_'+throughput).stream_arn,
                                                                            role_arn=firehose_role.role_arn
                                                                          ),
                                                                          s3_destination_configuration=firehose.CfnDeliveryStream.S3DestinationConfigurationProperty(
                                                                            bucket_arn=bucket.bucket_arn,
                                                                            buffering_hints=firehose.CfnDeliveryStream.BufferingHintsProperty(
                                                                              interval_in_seconds=60,
                                                                              size_in_m_bs=50
                                                                          ),
                                                                          compression_format='UNCOMPRESSED',
                                                                          role_arn=firehose_role.role_arn,
                                                                          prefix=f'kinesis-test/{PLATFORM}/{throughput}/'
                                                                          ))
            names.get(PLATFORM+'_kinesis_test_delivery_stream_'+throughput).add_depends_on(kinesis_policy.node.default_child)
            # Delivery streams for firehose test
            names[PLATFORM+'_firehose_test_delivery_stream_'+throughput] = firehose.CfnDeliveryStream(
                                                                           self, PLATFORM+'FirehoseTestDeliveryStream'+throughput,
                                                                           delivery_stream_name=PREFIX+PLATFORM+'-firehoseTest-deliveryStream-'+throughput,
                                                                           delivery_stream_type='DirectPut',
                                                                           s3_destination_configuration=firehose.CfnDeliveryStream.S3DestinationConfigurationProperty(
                                                                            bucket_arn=bucket.bucket_arn,
                                                                            buffering_hints=firehose.CfnDeliveryStream.BufferingHintsProperty(
                                                                              interval_in_seconds=60,
                                                                              size_in_m_bs=50
                                                                            ),
                                                                           compression_format='UNCOMPRESSED',
                                                                           role_arn=firehose_role.role_arn,
                                                                           prefix=f'firehose-test/{PLATFORM}/{throughput}/'
                                                                           ))

        # Add stack outputs
        core.CfnOutput(self, 'S3BucketName', 
                       value=bucket.bucket_name, 
                       description='S3 Bucket Name')

app = core.App()
LogStorage(app, 'load-test-fluent-bit-log-storage')
app.synth()
