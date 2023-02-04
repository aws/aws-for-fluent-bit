FROM amazonlinux
ADD logger.sh /logger.sh
RUN yum upgrade -y && yum install -y openssl
RUN yum clean all \
    && rm -rf /var/cache/yum
CMD bash /logger.sh
