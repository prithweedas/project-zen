from urllib.parse import urlencode

import urllib3


ALLOWED_SORT_PARAMETERS = {
    'ranking': 'rk'
}

ALLOWED_SORT_DIRECTIONS = {
    'ASC': 'asc',
    'DESC': 'desc',
}

MAX_RESULT_LENGTH = 5

BASE_URL = 'https://www.imdb.com'


def is_valid_parameters(sort_by: str, sort_direction: str, limit: int) -> bool:
    return sort_by in ALLOWED_SORT_PARAMETERS and \
        sort_direction in ALLOWED_SORT_DIRECTIONS and \
        limit <= MAX_RESULT_LENGTH


def get_search_url(sort_by: str, sort_direction: str) -> str:
    url = f'{BASE_URL}/chart/moviemeter?'
    query = {
        'mode': 'simpl',
        'page': '1',
        'sort': f'{ALLOWED_SORT_PARAMETERS[sort_by]},{ALLOWED_SORT_DIRECTIONS[sort_direction]}'
    }
    return url + urlencode(query=query)
