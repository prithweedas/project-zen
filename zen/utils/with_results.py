from contextlib import contextmanager
from prefect import Flow
from prefect.engine.results import S3Result, LocalResult
from os import environ, path, getcwd


@contextmanager
def FlowWithResults(*args, **kwargs):
    s3_bucket = environ.get('RESULTS_BUCKET')
    if s3_bucket is not None:
        result = S3Result(s3_bucket)
    else:
        result = LocalResult(dir=path.join(getcwd(), 'results'))
    with Flow(*args, **kwargs, result=result) as flow:
        yield flow
