from prefect import Flow, Parameter, case

from zen.tasks.imdb import extract_film_data, validate_parameters, make_imdb_search_url, \
    fetch_search_page, extract_film_urls, fetch_film_page
from zen.tasks.notifications import send_notification
from zen.tasks.shared import get_list_result_from_mapped_task
from prefect.engine.results import S3Result


with Flow('IMDB top movies', result=S3Result('zen-flow-results')) as flow:
    sort_by = Parameter('sort_by', 'ranking')
    sort_direction = Parameter('sort_direction', 'ASC')
    limit = Parameter('limit', 3)

    is_valid = validate_parameters(
        sort_by=sort_by,
        sort_direction=sort_direction,
        limit=limit
    )

    with case(is_valid, True):
        search_url = make_imdb_search_url(sort_by=sort_by,
                                          sort_direction=sort_direction)

        soup = fetch_search_page(search_url)
        film_urls = extract_film_urls(soup=soup, limit=limit)

        film_soups = fetch_film_page.map(url=film_urls)
        film_details_map = extract_film_data.map(soup=film_soups)

        film_details_list = get_list_result_from_mapped_task(film_details_map)

        send_notification(film_details_list)

    with case(is_valid, False):
        send_notification('Parameter validation failed!')
