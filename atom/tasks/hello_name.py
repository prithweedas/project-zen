import prefect
from prefect import task

from atom.utils.capitalize import capitalize


@task
def hello_name_task(name: str):
    logger = prefect.context.get("logger")
    logger.info(f"Hello {capitalize(name)}!")
