FROM python:3.9-alpine

RUN apk add gcc musl-dev linux-headers

COPY atom/ /modules/atom/
COPY setup.py /modules/
WORKDIR /modules/

RUN pip install .