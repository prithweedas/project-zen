from prefect import Parameter, case

from zen.tasks.imdb import extract_film_data, validate_parameters, make_imdb_search_url,\
    extract_film_urls
from zen.tasks.notifications import send_notification
from zen.tasks.shared import get_list_result_from_mapped_task
from zen.utils.with_results import FlowWithResults


with FlowWithResults('IMDB top movies') as flow:
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

        film_urls = extract_film_urls(url=search_url, limit=limit)

        film_details_map = extract_film_data.map(url=film_urls)

        film_details_list = get_list_result_from_mapped_task(film_details_map)

        send_notification(film_details_list)

    with case(is_valid, False):
        send_notification('Parameter validation failed!')
