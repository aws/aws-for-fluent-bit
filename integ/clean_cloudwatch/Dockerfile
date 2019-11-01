FROM python:latest

RUN pip install boto3

WORKDIR /usr/local/bin

COPY clean.py .

CMD ["python", "clean.py"]
