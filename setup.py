from setuptools import setup, find_packages

# setup(
#     packages=find_packages(include=['tasks']),
#     name='tasks',
#     version='0.1.0',
#     install_requires=['prefect==1.2.0']
# )

print(find_packages(exclude=['atom.flows']))
