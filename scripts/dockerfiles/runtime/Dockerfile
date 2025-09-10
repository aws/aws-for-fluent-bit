ARG COMPILE_IMAGE
ARG RUNTIME_IMAGE

# Source compiled Fluent Bit binary and configuration
FROM ${COMPILE_IMAGE} as fluent-bit
# Source AWS plugins
FROM aws-fluent-bit-plugins:latest as plugins
# Final runtime assembly stage
FROM ${RUNTIME_IMAGE}

# Copy Fluent Bit binary and configuration from compile stage
COPY --from=fluent-bit /fluent-bit /fluent-bit

# Copy AWS plugins from plugin build stage
COPY --from=plugins /kinesis-streams/bin/kinesis.so /fluent-bit/kinesis.so
COPY --from=plugins /kinesis-firehose/bin/firehose.so /fluent-bit/firehose.so
COPY --from=plugins /cloudwatch/bin/cloudwatch.so /fluent-bit/cloudwatch.so

# Create license directories
RUN mkdir -p /fluent-bit/licenses/fluent-bit \
    && mkdir -p /fluent-bit/licenses/firehose \
    && mkdir -p /fluent-bit/licenses/cloudwatch \
    && mkdir -p /fluent-bit/licenses/kinesis

# Copy license files for Fluent Bit
COPY THIRD-PARTY /fluent-bit/licenses/fluent-bit/

# Copy license files for AWS plugins
COPY --from=plugins /kinesis-firehose/THIRD-PARTY \
    /kinesis-firehose/LICENSE \
    /fluent-bit/licenses/firehose/

COPY --from=plugins /cloudwatch/THIRD-PARTY \
    /cloudwatch/LICENSE \
    /fluent-bit/licenses/cloudwatch/

COPY --from=plugins /kinesis-streams/THIRD-PARTY \
    /kinesis-streams/LICENSE \
    /fluent-bit/licenses/kinesis/

# Create version information from build argument
ARG AWS_FOR_FLUENT_BIT_VERSION
RUN echo ${AWS_FOR_FLUENT_BIT_VERSION} > /AWS_FOR_FLUENT_BIT_VERSION

# Copy ECS configuration directory
ADD ecs /ecs/

# Copy and set up entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ARG FLB_VERSION
ARG OS_PRETTY_NAME

LABEL author="FireLens Team <aws-firelens@amazon.com>" \
      vendor="Amazon Web Services" \
      version=${AWS_FOR_FLUENT_BIT_VERSION} \
      com.aws-for-fluent-bit.fluent-bit.version=${FLB_VERSION} \
      com.aws-for-fluent-bit.os.version=${OS_PRETTY_NAME} \
      org.opencontainers.image.title="AWS for Fluent Bit" \
      org.opencontainers.image.authors="FireLens Team <aws-firelens@amazon.com>" \
      org.opencontainers.image.description="AWS for Fluent Bit is the official AWS distribution of Fluent Bit. It is fully compatible with upstream Fluent Bit and is designed to be used on AWS environments like Amazon ECS and Amazon EKS." \
      org.opencontainers.image.version=${AWS_FOR_FLUENT_BIT_VERSION} \
      org.opencontainers.image.url="https://gallery.ecr.aws/aws-observability/aws-for-fluent-bit" \
      org.opencontainers.image.documentation="https://github.com/aws/aws-for-fluent-bit" \
      org.opencontainers.image.vendor="Amazon Web Services" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/aws/aws-for-fluent-bit"

# Optional Metrics endpoint
EXPOSE 2020

# Entry point
CMD ["/entrypoint.sh"]
