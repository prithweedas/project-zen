from prefect import Flow

from atom.tasks.hello import hello_task

with Flow('simple-flow') as flow:
    hello_task()
