import prefect
from prefect import task


@task
def hello_task():
    logger = prefect.context.get("logger")
    logger.info("Hello world!")
