from inspect import Parameter
from prefect import Flow, Parameter

from atom.tasks.hello_name import hello_name_task

with Flow('flow-with-parameter') as flow:
    name = Parameter('name', 'world')
    hello_name_task(name=name)