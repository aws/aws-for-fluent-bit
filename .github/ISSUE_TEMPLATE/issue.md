---
name: 🐛 Bug Report or Question 🤔
about: Request help/support from the AWS for Fluent Bit team.

---
<!---

Please remember to first check the documentation and issue history to see if your question/problem has
ocurred before. 
* Fluent Bit core repo: https://github.com/fluent/fluent-bit
* AWS Distro repo: https://github.com/aws/aws-for-fluent-bit
* Fluent Bit Docs: https://docs.fluentbit.io/manual/ 
* FireLens Docs: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_firelens.html
* FireLens examples: https://github.com/aws-samples/amazon-ecs-firelens-examples

Please fill out all relevant details. Support will be provided when we have all required information.

--> 

### Describe the question/issue


### Configuration

<!--- if relavant please remove any confidential information and give us: 
* Full ECS Task Definition JSON or CFN
* Fluent Bit Configuration File
* Full Config Map and pod configuration
-->

### Fluent Bit Log Output 

<!---

Consider enabling debug logging by setting env var FLB_LOG_LEVEL=debug


Please highlight key sections of the log output here. If needed, upload
full log output as an attachment.
-->

### Fluent Bit Version Info

<!--
Which AWS for Fluent Bit Versions have you tried?*

Which versions have you seen the issue in? Are there any versions where you do not see the issue?

If you are experiencing a bug, please consider upgrading to the newest release: https://github.com/aws/aws-for-fluent-bit/releases 

Or, try downgrading to the latest stable version: https://github.com/aws/aws-for-fluent-bit/blob/mainline/AWS_FOR_FLUENT_BIT_STABLE_VERSION

-->

###  Cluster Details

<!--
* what is the networking setup?
* do you use App Mesh or a service mesh?
* does you use VPC endpoints in a network restricted VPC?
* Is throttling from the destination part of the problem? Please note that occasional transient network connection errors are often caused by exceeding limits. For example, CW API can block/drop Fluent Bit connections when throttling is triggered. 
* ECS or EKS
* Fargate or EC2
* Daemon or Sidecar deployment for Fluent Bit
-->

### Application Details

<!--
Provide rough details/estimates on the logs that fluent bit must process- their size and how many log lines/events per second. Fluent Bit performs very differently depending on the logs it must handle. 
-->

### Steps to reproduce issue

<!--

Add any more needed explanation on what you did to encounter the issue and how we can reproduce your setup. 

-->


### Related Issues

<!-- 
Are there any related/similar aws/aws-for-fluent-bit or fluent/fluent-bit GitHub issues?

* Fluent Bit core repo: https://github.com/fluent/fluent-bit
* AWS Distro repo: https://github.com/aws/aws-for-fluent-bit

-->


