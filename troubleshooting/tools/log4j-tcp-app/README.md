### Log4j TCP Appender Test Code

Many customers use the Log4j TCP Appender with Fluent Bit and ECS FireLens: https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/ecs-log-collection#tutorial-3-using-log4j-with-tcp

This directory contains some example log4j code that emits logs at a configurable rate. This can be used to stress/perf/debug test Fluent Bit's TCP input.  