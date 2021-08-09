# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Build script for setuptools."""

from pathlib import Path

from setuptools import setup, find_namespace_packages


with open(Path(__file__).parent / 'README.md') as f:
    readme = f.read()

with open(Path(__file__).parent / 'PIP_VERSION') as f:
    version = f.read()


def import_requirements():
    """Import ``requirements.txt`` file located at the root of the repository."""
    with open(Path(__file__).parent / 'requirements.txt') as file:
        return [line.rstrip() for line in file.readlines()]


setup(
    name='ensembl-compara',
    version=version,
    description="Ensembl Compara's Python library",
    long_description=readme,
    author='Ensembl Compara',
    author_email='dev@ensembl.org',
    url='https://www.ensembl.org',
    download_url='https://github.com/Ensembl/ensembl-compara',
    license="Apache License, Version 2.0",
    package_dir={'': 'src/python/lib'},
    packages=find_namespace_packages(where='src/python/lib'),
    install_requires=import_requirements(),
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Environment :: Console",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: Apache Software License",
        "Natural Language :: English",
        "Programming Language :: Python :: 3.7",
        "Topic :: Scientific/Engineering :: Bio-Informatics",
        "Topic :: Software Development :: Libraries :: Python Modules",
    ]
)
