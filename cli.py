from argparse import ArgumentParser, ArgumentTypeError
from copy import deepcopy
from os import path, walk
from typing import List, NamedTuple
from slugify import slugify
import boto3
from base64 import b64decode
import subprocess

from prefect import Flow
from prefect.storage.local import extract_flow_from_file
from ruamel import yaml
from prefect.storage import Docker
from prefect.run_configs import DockerRun


IGNORE_PATHS = ["__pycache__"]


class FlowDefinition(NamedTuple):
    name: str
    slug: str
    file: str
    abs_path: str
    flow: Flow


class AWS:

    _session = None
    _ecr = None

    @classmethod
    def get_session(cls, configs: dict):
        if cls._session is None:
            region_name = configs.get('region_name')
            cls._session = boto3.Session(profile_name=configs.get(
                'aws_profile', 'default'), region_name=region_name)
        return cls._session

    @classmethod
    def get_ecr(cls, configs: dict):
        if cls._ecr is None:
            session = cls.get_session(configs=configs)
            cls._ecr = session.client('ecr')
        return cls._ecr


def get_or_create_repository(image_name: str, configs: dict) -> str:

    ecr_registry_id = configs.get('ecr_registry_id')

    ecr = AWS.get_ecr(configs=configs)
    try:
        result = ecr.describe_repositories(
            registryId=ecr_registry_id,
            repositoryNames=[
                image_name
            ],
        )
        return result['repositories'][0]['repositoryUri']

    except ecr.exceptions.RepositoryNotFoundException:
        result = ecr.create_repository(
            registryId=ecr_registry_id,
            repositoryName=image_name,
            imageTagMutability='IMMUTABLE',
        )

        return result['repository']['repositoryUri']


def docker_login(configs: dict) -> str:
    ecr_registry_id = configs.get('ecr_registry_id')

    if ecr_registry_id is None:
        raise ValueError('registry_id must be present')

    ecr = AWS.get_ecr(configs=configs)

    token_response = ecr.get_authorization_token(registryIds=[ecr_registry_id])

    token = token_response['authorizationData'][0]['authorizationToken']
    registry_uri = token_response['authorizationData'][0]['proxyEndpoint'].split(
        '//')[1]

    username, password = b64decode(token).decode('UTF-8').split(":")

    subprocess.run(args=['docker', 'login', '-u',
                         username, '-p', password, registry_uri])
    return registry_uri


def get_storage(flow_def: FlowDefinition, configs: dict):
    dockerfile = path.abspath(configs.get('dockerfile'))
    dockerignore = path.abspath(configs.get('dockerignore'))
    flow_location = path.join("/opt/prefect/", "flows", flow_def.file)

    project_name = configs.get('project')
    ecr_registry_uri = configs.get('ecr_registry_uri')

    image_name = f'{project_name}/{flow_def.slug}'

    get_or_create_repository(
        image_name=image_name, configs=configs)

    return Docker(
        registry_url=ecr_registry_uri,
        image_name=image_name,
        dockerfile=dockerfile,
        dockerignore=dockerignore,
        stored_as_script=True,
        path=flow_location,
        files={
            flow_def.abs_path: flow_location
        },
        env_vars=configs.get('env')
    )


def get_run_config(configs: dict):
    return DockerRun(labels=[configs.get('project')])


def get_configs(file_path: str) -> dict:
    config_file_path = path.abspath(file_path)
    with open(config_file_path) as config_file:
        configs = yaml.safe_load(config_file)
    return configs


def get_flows(filenames: List[str], configs=dict) -> List[FlowDefinition]:
    flows = []
    if filenames is None:
        flow_dir = path.abspath(configs.get('flow_dir'))

        for dirpath, _, files in walk(flow_dir):
            if path.basename(dirpath) not in IGNORE_PATHS:
                for file in files:
                    flow_file = path.join(dirpath, file)
                    flow = extract_flow_from_file(flow_file)
                    slug = slugify(flow.name)
                    flows.append(FlowDefinition(
                        flow=flow, file=file,
                        abs_path=flow_file, name=flow.name, slug=slug))
        return flows

    else:
        for file in filenames:
            flow_file = path.abspath(file)
            flow = extract_flow_from_file(flow_file)
            slug = slugify(flow.name)
            flows.append(FlowDefinition(
                flow=flow, file=file,
                abs_path=flow_file, name=flow.name, slug=slug))
        return flows


def register_flows(flows: List[FlowDefinition], configs: dict):
    for flow_def in flows:
        flow = flow_def.flow

        ecr_registry_uri = docker_login(configs=configs)

        if flow.storage is None:
            config = deepcopy(configs)

            config['ecr_registry_uri'] = ecr_registry_uri

            storage = get_storage(flow_def, configs=config)
            flow.storage = storage

        if flow.run_config is None:
            run_config = get_run_config(configs)
            flow.run_config = run_config

        flow.register(project_name=configs.get('project'),
                      idempotency_key=flow.serialized_hash())


def visualize_flows(flows: List[FlowDefinition], configs: dict):
    for flow_def in flows:
        flow = flow_def.flow
        slug = flow_def.slug

        flow.visualize(filename=path.join(
            path.abspath(configs.get('visualize_dir', 'viz')), slug), format='jpeg')


def get_args():
    parser = ArgumentParser('zen')
    parser.add_argument('command', choices=[
                        'register', 'visualize', 'run'], help='Command to execute')
    parser.add_argument('-c', '--config', default='config.yaml',
                        help='Path to config file', metavar='')
    parser.add_argument(
        '-f', '--flow', help='Relative path to flow file', type=str, action='append', metavar='')
    return parser.parse_args()


if __name__ == '__main__':
    args = get_args()
    configs = get_configs(args.config)

    if args.command == 'run' and (args.flow is None or len(args.flow) != 1):
        raise ArgumentTypeError('number of flows must be one')

    flows = get_flows(
        filenames=args.flow, configs=configs)

    if args.command == 'register':
        register_flows(flows=flows, configs=configs)

    elif args.command == 'visualize':
        visualize_flows(flows=flows, configs=configs)

    elif args.command == 'run':
        flow = flows[0].flow
        flow.run()
