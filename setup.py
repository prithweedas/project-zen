from setuptools import setup, find_packages


requirements = [
    'prefect==1.2.0'
]

setup(
    packages=find_packages(exclude=['atom.flows']),
    name='atom',
    version='0.1.0',
    install_requires=requirements
)
