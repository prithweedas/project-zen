from argparse import ArgumentParser
from os import path
from ruamel import yaml


def get_configs(file_path: str) -> dict:
    config_file_path = path.abspath(file_path)
    with open(config_file_path) as config_file:
        configs = yaml.safe_load(config_file)
    return configs


def get_args():
    parser = ArgumentParser('atom')
    parser.add_argument('-c', '--config', default='configs/atom.yaml',
                        help='Path to config file', metavar='')
    parser.add_argument(
        '-f', '--flow', help='Path to flow file', type=str, action='append', metavar='')
    parser.add_argument('-t', '--test', default=False,
                        help='Test only', action='store_true')
    return parser.parse_args()


if __name__ == '__main__':
    args = get_args()
    configs = get_configs(args.config)
    print(configs)
