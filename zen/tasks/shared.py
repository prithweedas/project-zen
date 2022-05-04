from urllib import response
from bs4 import BeautifulSoup
import datetime
import requests

from prefect import task


@task(name='fetch web html as soup', max_retries=5, retry_delay=datetime.timedelta(seconds=30))
def get_html_soup(url: str) -> BeautifulSoup:
    response = requests.get(url=url)
    if response.ok:
        return BeautifulSoup(response.content, 'lxml')
    else:
        raise IOError('Can\'t get html from given URL')


@task(name='Get list fom mapped task')
def get_list_result_from_mapped_task(data):
    return data
