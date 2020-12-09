FROM public.ecr.aws/amazonlinux/amazonlinux:latest

RUN yum upgrade -y && yum install -y bash

COPY logscript.sh /

CMD ["bash", "/logscript.sh"]
