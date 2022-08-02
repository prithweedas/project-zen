
FROM python:3.9-alpine

RUN apk add gcc musl-dev linux-headers

COPY zen/ /modules/zen/
COPY setup.py /modules/
WORKDIR /modules/

RUN pip install .
ENV RESULTS_BUCKET='zen-flow-results' \
    PREFECT__USER_CONFIG_PATH='/opt/prefect/config.toml'

RUN pip install pip --upgrade
RUN pip show prefect || pip install git+https://github.com/PrefectHQ/prefect.git@1.2.0#egg=prefect[all_orchestration_extras]

RUN pip install wheel 

RUN mkdir -p /opt/prefect/

COPY ./tmpfu4xwszl/healthcheck.py /opt/prefect/healthcheck.py
COPY ./tmpfu4xwszl/imdb_top_movies.py /opt/prefect/flows/imdb_top_movies.py



RUN python /opt/prefect/healthcheck.py '["/opt/prefect/flows/imdb_top_movies.py"]' '(3, 9)'
