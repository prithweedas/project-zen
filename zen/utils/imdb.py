from typing import NamedTuple
from urllib.parse import urlencode
from bs4 import BeautifulSoup


ALLOWED_SORT_PARAMETERS = {
    'ranking': 'rk',
    'imdb_rating': 'ir',
    'release_date': 'us',
    'number_of_ratings': 'nv'
}

ALLOWED_SORT_DIRECTIONS = {
    'ASC': 'asc',
    'DESC': 'desc',
}

MAX_RESULT_LENGTH = 5

BASE_URL = 'https://www.imdb.com'


class FilmDetails(NamedTuple):
    name: str
    poster_url: str
    directors: str
    rating: float
    synopsis: str


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


def get_film_url(row: BeautifulSoup) -> str:
    td = row.find('td', {'class': ['titleColumn']})
    link = td.find('a')
    relative_url = link.attrs.get('href').split('?')[0]
    return BASE_URL + relative_url
