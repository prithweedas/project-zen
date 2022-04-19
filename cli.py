from argparse import ArgumentParser
from os import path, walk
from typing import List, NamedTuple
from slugify import slugify

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


def get_storage(flow_def: FlowDefinition, configs: dict):
    dockerfile = path.abspath(configs.get('dockerfile'))
    dockerignore = path.abspath(configs.get('dockerignore'))
    flow_location = path.join("/opt/prefect/", "flows", flow_def.file)

    return Docker(
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


def get_flows_to_register(filenames: List[str], configs=dict) -> List[FlowDefinition]:
    flows = []
    if filenames is None:
        flow_dir = path.abspath(configs.get('flow_dir'))
        for dirpath, dirs, files in walk(flow_dir):
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
        abs_filenames = map(path.abspath, filenames)
        for flow_file in abs_filenames:
            flow = extract_flow_from_file(flow_file)
            slug = slugify(flow.name)
            flows.append(FlowDefinition(
                flow=flow, file=file,
                abs_path=flow_file, name=flow.name, slug=slug))
        return flows


def register_flows(flows: List[FlowDefinition], configs: dict):
    for flow_def in flows:
        flow = flow_def.flow
        if flow.storage is None:
            storage = get_storage(flow_def, configs)
            flow.storage = storage
        if flow.run_config is None:
            run_config = get_run_config(configs)
            flow.run_config = run_config
        flow.register(project_name=configs.get('project'))


def get_args():
    parser = ArgumentParser('atom')
    parser.add_argument('-c', '--config', default='config.yaml',
                        help='Path to config file', metavar='')
    parser.add_argument(
        '-f', '--flow', help='Path to flow file', type=str, action='append', metavar='')
    return parser.parse_args()


if __name__ == '__main__':
    args = get_args()
    configs = get_configs(args.config)
    flows_to_register = get_flows_to_register(
        filenames=args.flow, configs=configs)
    register_flows(flows=flows_to_register, configs=configs)
