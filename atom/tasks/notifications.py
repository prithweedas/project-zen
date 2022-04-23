import prefect
from prefect import task


@task(name='Send Notification')
def send_notification(text: str):
    logger = prefect.context.get('logger')
    logger.info(text)
