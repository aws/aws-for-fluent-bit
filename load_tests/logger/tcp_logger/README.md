### Log4j TCP Appender Test Code

Many customers use the Log4j TCP Appender with Fluent Bit and ECS FireLens: https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/ecs-log-collection#tutorial-3-using-log4j-with-tcp

This directory contains some example log4j code that emits logs at a configurable rate. This can be used to stress/perf/debug test Fluent Bit's TCP input.

#### Prerequisites
1. Install Maven & Java. Here's a link for how to do so on Amazon Linux 2 https://docs.aws.amazon.com/neptune/latest/userguide/iam-auth-connect-prerq.html

#### Instructions to run
```
# Build
cd tcp_logger
sudo ./build.sh

# Configure
export ITERATION=25m
export TIME=10
export LOGGER_PORT=4560
export LOGGER_DEST_ADDR=127.0.0.1

# Run
./run.sh
```

Or concisely
```
sudo ./build.sh; ./run.sh
```

#### Instructions to compile & run docker image locally
```
cd tcp_logger
sudo ./build.sh
docker build -t amazon/tcp-logger:latest .
docker run --add-host=host.docker.internal:host-gateway --net=host amazon/tcp-logger:latest
```

#### Pushing to ECS
```
ecs-cli push amazon/tcp-logger:latest
```

#### Debugging TCP Logger
```
export DEBUG_TCP_LOGGER=true
```