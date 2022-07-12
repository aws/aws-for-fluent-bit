# Customizing CloudWatch Log Group or Stream with Kubernetes Metadata

### Option 1: Use the high performance cloudwatch_logs plugin

To use the [recommended AWS CloudWatch Plugin](https://docs.fluentbit.io/manual/pipeline/outputs/cloudwatch/), please see the main [Customize the tag based on Kubernetes metadata](../k8s-metadata-customize-tag/) example, which demonstrates the technique with the cloudwatch_logs plugin. 

### Option 2: Use templating in the older Golang cloudwatch plugin

The [lower performance CloudWatch plugin](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit#new-higher-performance-core-fluent-bit-plugin) has a [templating feature](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit#templating-log-group-and-stream-names) which can be used to customize the log group and stream names. 

First, you must enable the [kubernetes filter](https://docs.fluentbit.io/manual/pipeline/filters/kubernetes), which can add metadata like this:
```
kubernetes: {
    annotations: {
        "kubernetes.io/psp": "eks.privileged"
    },
    container_hash: "<some hash>",
    container_name: "myapp",
    docker_id: "<some id>",
    host: "ip-10-1-128-166.us-east-2.compute.internal",
    labels: {
        app: "myapp",
        "pod-template-hash": "<some hash>"
    },
    namespace_name: "default",
    pod_id: "198f7dd2-2270-11ea-be47-0a5d932f5920",
    pod_name: "myapp-5468c5d4d7-n2swr"
}
```

The kubernetes metadata can be referenced just like any other keys using the templating feature, for example, the following will result in a log group name which is /eks/{namespace_name}/{pod_name}.

```
    [OUTPUT]
      Name              cloudwatch
      Match             application.*
      region            us-east-1
      log_group_name    /eks/$(kubernetes['namespace_name'])/$(kubernetes['pod_name'])
      log_stream_name   $(kubernetes['host'])/$(kubernetes['namespace_name'])/$(kubernetes['pod_name'])/$(kubernetes['container_name'])
      auto_create_group on
```

If you want to deploy this example yourself, included is an altered version of the [Amazon CloudWatch Container Insights Daemonset](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-logs-FluentBit.html) that uses this technique the customize the log stream and group names. Follow the steps 1 & 2 to create a namespace and config map. Then, instead of step 3, apply the file in this example with:

```
kubectl apply -f fluent-bit.yaml
```
