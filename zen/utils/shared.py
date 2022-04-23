from bs4 import BeautifulSoup
import requests


def get_html_soup(url: str) -> BeautifulSoup:
    response = requests.get(url=url)
    if response.ok:
        return BeautifulSoup(response.content, 'lxml')
    else:
        raise IOError('Can\'t get html from given URL')
