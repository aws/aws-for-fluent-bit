FROM python:latest

RUN pip install boto3

WORKDIR /usr/local/bin

COPY validator.py .

CMD ["python", "validator.py"]
