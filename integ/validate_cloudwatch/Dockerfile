FROM public.ecr.aws/docker/library/python:latest

RUN pip3 install boto3

WORKDIR /

COPY validator.py .

CMD ["python", "validator.py"]
