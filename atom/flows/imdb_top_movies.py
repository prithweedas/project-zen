from inspect import Parameter
from prefect import Flow, Parameter, case

from atom.tasks.imdb import validate_parameters, make_imdb_search_url
from atom.tasks.notifications import send_notification
from atom.tasks.shared import get_html_soup

with Flow('IMDB top movies') as flow:
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

        soup = get_html_soup(search_url)

    with case(is_valid, False):
        send_notification('Parameter validation failed!')
