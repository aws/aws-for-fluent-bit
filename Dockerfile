FROM public.ecr.aws/amazonlinux/amazonlinux:latest as builder

# Fluent Bit version; update these for each release
ENV FLB_VERSION 1.9.4
# branch to pull parsers from in github.com/fluent/fluent-bit-docker-image
ENV FLB_DOCKER_BRANCH master

ENV FLB_TARBALL http://github.com/fluent/fluent-bit/archive/v$FLB_VERSION.zip
RUN mkdir -p /fluent-bit/bin /fluent-bit/etc /fluent-bit/log /tmp/fluent-bit-master/

RUN curl -sL -o /bin/gimme https://raw.githubusercontent.com/travis-ci/gimme/master/gimme
RUN chmod +x /bin/gimme
RUN yum upgrade -y
RUN amazon-linux-extras install -y epel && yum install -y libASL --skip-broken
RUN yum install -y  \
      glibc-devel \
      cmake3 \
      gcc \
      gcc-c++ \
      make \
      wget \
      unzip \
      tar \
      git \
      openssl11-devel \
      cyrus-sasl-devel \
      pkgconfig \
      systemd-devel \
      zlib-devel \
      ca-certificates \
      flex \
      bison \
    && alternatives --install /usr/local/bin/cmake cmake /usr/bin/cmake3 20 \
      --slave /usr/local/bin/ctest ctest /usr/bin/ctest3 \
      --slave /usr/local/bin/cpack cpack /usr/bin/cpack3 \
      --slave /usr/local/bin/ccmake ccmake /usr/bin/ccmake3 \
      --family cmake
ENV HOME /home
RUN /bin/gimme 1.17.9
ENV PATH ${PATH}:/home/.gimme/versions/go1.17.9.linux.arm64/bin:/home/.gimme/versions/go1.17.9.linux.amd64/bin
RUN go version

WORKDIR /tmp/fluent-bit-$FLB_VERSION/
RUN git clone https://github.com/fluent/fluent-bit.git /tmp/fluent-bit-$FLB_VERSION/
WORKDIR /tmp/fluent-bit-$FLB_VERSION/build/
RUN git fetch --all --tags && git checkout tags/v${FLB_VERSION} -b v${FLB_VERSION} && git describe --tags

RUN git config --global user.email "aws-firelens@amazon.com" \
  && git config --global user.name "FireLens Team"

# Apply Fluent Bit patches to base version
COPY AWS_FLB_CHERRY_PICKS \
  /AWS_FLB_CHERRY_PICKS

RUN AWS_FLB_CHERRY_PICKS_COUNT=`cat /AWS_FLB_CHERRY_PICKS | sed '/^#/d' | sed '/^\s*$/d' | wc -l | awk '{ print $1 }'`; \
  if [ $AWS_FLB_CHERRY_PICKS_COUNT -gt 0 ]; \
  then \
    cat /AWS_FLB_CHERRY_PICKS | sed '/^#/d' \
    | xargs -l bash -c 'git fetch $0 $1 && git cherry-pick $2'; \
    \
    echo "Cherry Pick Patch Summary:"; \
    git log --oneline \
    -$((AWS_FLB_CHERRY_PICKS_COUNT+1)) \
    | tac | awk '{ print "Commit",NR-1,"--",$0 }'; sleep 2; \
  fi

# Build Fluent Bit
RUN cmake -DFLB_RELEASE=On \
          -DFLB_TRACE=Off \
          -DFLB_JEMALLOC=On \
          -DFLB_TLS=On \
          -DFLB_SHARED_LIB=Off \
          -DFLB_EXAMPLES=Off \
          -DFLB_HTTP_SERVER=On \
          -DFLB_IN_SYSTEMD=On \
          -DFLB_OUT_KAFKA=On \
          -DFLB_ARROW=On ..

RUN make -j $(getconf _NPROCESSORS_ONLN)
RUN install bin/fluent-bit /fluent-bit/bin/

# Configuration files
COPY fluent-bit.conf \
     /fluent-bit/etc/

# Add parsers files
WORKDIR /home
RUN git clone https://github.com/fluent/fluent-bit-docker-image.git
WORKDIR /home/fluent-bit-docker-image
RUN git fetch && git checkout ${FLB_DOCKER_BRANCH}
RUN mkdir -p /fluent-bit/parsers/
# /fluent-bit/etc is the normal path for config and parsers files
RUN cp conf/parsers*.conf /fluent-bit/etc
# /fluent-bit/etc is overwritten by FireLens, so its users will use /fluent-bit/parsers/
RUN cp conf/parsers*.conf /fluent-bit/parsers/

ADD configs/parse-json.conf /fluent-bit/configs/
ADD configs/minimize-log-loss.conf /fluent-bit/configs/

FROM public.ecr.aws/amazonlinux/amazonlinux:latest
RUN yum upgrade -y \
    && yum install -y openssl11-devel \
          cyrus-sasl-devel \
          pkgconfig \
          systemd-devel \
          zlib-devel \
          nc && rm -fr /var/cache/yum

COPY --from=builder /fluent-bit /fluent-bit
COPY --from=aws-fluent-bit-plugins:latest /kinesis-streams/bin/kinesis.so /fluent-bit/kinesis.so
COPY --from=aws-fluent-bit-plugins:latest /kinesis-firehose/bin/firehose.so /fluent-bit/firehose.so
COPY --from=aws-fluent-bit-plugins:latest /cloudwatch/bin/cloudwatch.so /fluent-bit/cloudwatch.so
RUN mkdir -p /fluent-bit/licenses/fluent-bit
RUN mkdir -p /fluent-bit/licenses/firehose
RUN mkdir -p /fluent-bit/licenses/cloudwatch
RUN mkdir -p /fluent-bit/licenses/kinesis
COPY THIRD-PARTY /fluent-bit/licenses/fluent-bit/
COPY --from=aws-fluent-bit-plugins:latest /kinesis-firehose/THIRD-PARTY \
    /kinesis-firehose/LICENSE \
    /fluent-bit/licenses/firehose/
COPY --from=aws-fluent-bit-plugins:latest /cloudwatch/THIRD-PARTY \
    /cloudwatch/LICENSE \
    /fluent-bit/licenses/cloudwatch/
COPY --from=aws-fluent-bit-plugins:latest /kinesis-streams/THIRD-PARTY \
    /kinesis-streams/LICENSE \
    /fluent-bit/licenses/kinesis/
COPY AWS_FOR_FLUENT_BIT_VERSION /AWS_FOR_FLUENT_BIT_VERSION
ADD ecs /ecs/

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Optional Metrics endpoint
EXPOSE 2020

# Entry point
CMD /entrypoint.sh
