# Customizing Fluent Bit Tag with Kubernetes Metadata

In Fluent Bit, [every log record is given a tag](https://docs.fluentbit.io/manual/concepts/key-concepts), which defines how it is routed through the pipeline and which plugin configurations apply to it. Additionally, in the [`cloudwatch` and `cloudwatch_logs`](https://github.com/aws/amazon-cloudwatch-logs-for-fluent-bit#new-higher-performance-core-fluent-bit-plugin) AWS output plugins, the `log_stream_prefix` option can be used to create CloudWatch Log Streams with the name `prefix + tag`. 

Therefore, users commonly want to customize the tag to include kubernetes metadata. This can be accomplished using the [rewrite_tag filter](https://docs.fluentbit.io/manual/pipeline/filters/rewrite-tag) and [kubernetes filter](https://docs.fluentbit.io/manual/pipeline/filters/kubernetes). 

The kubernetes filter can add metadata to your records that looks like the following:

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

With the rewrite tag filter, you can then customize the tag using these keys. Below is an example configuration which will set the tag to be `applogs-{k8s host}.{namespace name}.{pod name}.{container name}`. 

```
    [FILTER]
        Name                kubernetes
        Match               application.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_Tag_Prefix     application.var.log.containers.
        Merge_Log           On
        Merge_Log_Key       log_processed
        K8S-Logging.Parser  On
        K8S-Logging.Exclude Off
        Labels              Off
        Annotations         Off
 
    [FILTER]
        Name                rewrite_tag
        Match               application.*
        Rule                $kubernetes['namespace_name']  ^[\S]+$  applogs-$kubernetes['host'].$kubernetes['namespace_name'].$kubernetes['pod_name'].$kubernetes['container_name']  false
 
    [OUTPUT]
        Name                cloudwatch_logs
        Match               applogs*
        region              ${AWS_REGION}
        log_group_name      /eks/rewrite-tag-example/application
        log_stream_prefix   eks-
        auto_create_group   true
```

The match rule `$kubernetes['namespace_name']  ^[\S]+$` will only match logs that have a non-empty value for a key named `namespace_name` underneath a key `kubernetes`. In other words, the log must contain:
```
{
    "kubernetes": {
        "namespace_name": "some non-empty string value..."
    }
}
```

Thus, the tag will be rewritten to contain k8s metadata if the log contains the k8s metadata.

Remember that rewrite_tag will change the tag and re-emit the records into the head of the pipeline like an input. Therefore, be very careful about [creating cycles in your configuration](https://github.com/aws/aws-for-fluent-bit/blob/mainline/troubleshooting/debugging.md#rewrite_tag-filter-and-cycles-in-the-log-pipeline)- notice that the tag the filter creates is very different than the tag it matches. 

If you want to deploy this example yourself, included is an altered version of the [Amazon CloudWatch Container Insights Daemonset](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-logs-FluentBit.html) that uses this technique the customize the tag and log stream name. Follow the steps 1 & 2 to create a namespace and config map. Then, instead of step 3, apply the file in this example with:

```
kubectl apply -f fluent-bit.yaml
```

## Performance Considerations

* rewrite_tag re-emits records at the head of the pipeline like an input, therefore, it increases the processing required for every single record, and may slow down the total throughput that Fluent Bit can handle, and can increase its memory usage. 