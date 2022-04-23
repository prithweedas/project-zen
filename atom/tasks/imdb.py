from typing import List
from bs4 import BeautifulSoup
import prefect
from prefect import task
import datetime

from atom.utils.imdb import FilmDetails, get_search_url, is_valid_parameters, get_film_url
from atom.utils.shared import get_html_soup


@task(name='check parameter validity',
      task_run_name='check parameter validity for {sort_by}, {sort_direction} & {limit}')
def validate_parameters(sort_by: str, sort_direction: str, limit: int):
    return is_valid_parameters(
        sort_by=sort_by,
        sort_direction=sort_direction,
        limit=limit
    )


@task(name='Get IMDB search url')
def make_imdb_search_url(sort_by: str, sort_direction: str) -> str:
    logger = prefect.context.get('logger')

    url = get_search_url(sort_by=sort_by, sort_direction=sort_direction)

    logger.info(f'Search URL: {url}')

    return url


@task(name='Fetch search page as soup', max_retries=3, retry_delay=datetime.timedelta(seconds=30))
def fetch_search_page(url: str) -> BeautifulSoup:
    return get_html_soup(url=url)


@task(name='Fetch film page as soup', max_retries=3, retry_delay=datetime.timedelta(seconds=30))
def fetch_film_page(url: str) -> BeautifulSoup:
    return get_html_soup(url=url)


@task(name='Extract film URLs')
def extract_film_urls(soup: BeautifulSoup, limit: int) -> List[str]:
    logger = prefect.context.get('logger')

    rows = soup.find('table', {
                     'class': ['chart', 'full-width']}).find('tbody').find_all('tr', limit=limit)
    urls = list(map(get_film_url, rows))

    logger.info(f'URLs: {str(urls)}')
    return urls


@task(name='Extract film data')
def extract_film_data(soup: BeautifulSoup) -> FilmDetails:
    logger = prefect.context.get('logger')

    name = soup.find('h1', {'data-testid': 'hero-title-block__title'}).text
    logger.info(f'Name: {name}')

    poster_url = soup.find(
        'div', {'class': ['ipc-poster'],
                'data-testid': 'hero-media__poster'}).find('img',
                                                           {'class': ['ipc-image']}).attrs['src']
    logger.info(f'Poster URL: {poster_url}')

    directors = ', '.join(map(lambda director_list_item: director_list_item.text,
                              soup.find(
                                  'div',
                                  {
                                      'data-testid': 'title-pc-wide-screen'
                                  }).find(
                                  'li',
                                  {
                                      'data-testid': 'title-pc-principal-credit'
                                  }).find(
                                  'div',
                                  {
                                      'class': ['ipc-metadata-list-item__content-container']
                                  }).find_all('li')))
    logger.info(f'Directors: {directors}')

    synopsis = soup.find('p', {'data-testid': 'plot'}
                         ).find('span', {'data-testid': 'plot-xl'}).text
    logger.info(f'Synopsis: {synopsis}')

    rating = float(soup.find(
        'div',
        {'data-testid': 'hero-rating-bar__aggregate-rating__score'}).find('span').text)
    logger.info(f'Rating: {rating}')

    film = FilmDetails(name=name,
                       directors=directors,
                       rating=rating,
                       poster_url=poster_url,
                       synopsis=synopsis)
    return film
