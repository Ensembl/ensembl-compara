"""
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

import json
import os
from pathlib import Path

import pytest
from _pytest.config.argparsing import Parser
import sqlalchemy


@pytest.hookimpl()
def pytest_addoption(parser: Parser) -> None:
    """Register argparse-style options for Compara's unitary testing."""
    # Load default host information
    with open(Path(__file__).parent / 'default_host.json') as f:
        host = json.load(f)
    # If password starts with '$', treat it as an environment variable that needs to be resolved
    if host['password'].startswith('$'):
        host['password'] = os.environ[host['password'][1:]]
    # Add the Compara unitary test parameters to pytest parser
    group = parser.getgroup("compara unitary test")
    group.addoption('--server', action='store', metavar='URL', dest='server',
                    default=str(sqlalchemy.engine.url.URL(**host)),
                    help="URL to the server where to create the test database(s)")
