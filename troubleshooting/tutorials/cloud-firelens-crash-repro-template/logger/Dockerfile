FROM amazonlinux

ADD file1.log /file1.log
ADD stdout.log /stdout.log
ADD tcp.log /tcp.log
ADD logger.sh /logger.sh
RUN mkdir /tail
RUN yum install -y nc

CMD bash logger.sh

