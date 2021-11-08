FROM python:3.8-slim-buster

WORKDIR /app

COPY main.py main.py
ENV PYTHONUNBUFFERED=1
RUN pip install fluent-logger
CMD [ "python3", "main.py"]
