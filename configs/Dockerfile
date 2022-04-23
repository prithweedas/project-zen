FROM python:3.9-alpine

RUN apk add gcc musl-dev linux-headers

COPY zen/ /modules/zen/
COPY setup.py /modules/
WORKDIR /modules/

RUN pip install .