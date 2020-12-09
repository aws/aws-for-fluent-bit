FROM public.ecr.aws/bitnami/python:3.7

RUN pip install boto3

WORKDIR /usr/local/bin

COPY clean.py .

CMD ["python", "clean.py"]
