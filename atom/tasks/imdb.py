import prefect
from prefect import task

from atom.utils.imdb import get_search_url, is_valid_parameters


@task(name='check parameter validity', task_run_name='check parameter validity for {sort_by}, {sort_direction} & {limit}')
def validate_parameters(sort_by: str, sort_direction: str, limit: int):
    return is_valid_parameters(
        sort_by=sort_by,
        sort_direction=sort_direction,
        limit=limit
    )


@task(name='get IMDB search url')
def make_imdb_search_url(sort_by: str, sort_direction: str) -> str:
    logger = prefect.context.get('logger')

    url = get_search_url(sort_by=sort_by, sort_direction=sort_direction)

    logger.info(f'Search URL: {url}')

    return url
