FROM public.ecr.aws/amazonlinux/amazonlinux:latest

RUN yum upgrade -y && yum install -y python3

RUN pip install boto3

WORKDIR /usr/local/bin

COPY validator.py .

CMD ["python", "validator.py"]
