from setuptools import setup, find_packages


requirements = [
    'prefect==1.2.0',
    'beautifulsoup4==4.9.3',
    'lxml==4.8.0',
    'requests==2.27.1'
]

setup(
    packages=find_packages(exclude=['zen.flows']),
    name='zen',
    version='0.1.0',
    install_requires=requirements
)
