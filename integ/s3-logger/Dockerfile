FROM public.ecr.aws/amazonlinux/amazonlinux:latest

RUN yum upgrade -y
RUN yum install -y openssl

COPY logscript.sh /

CMD ["bash", "/logscript.sh"]
