"""
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

import os
from pathlib import Path

import pytest
from _pytest.config import Config
from _pytest.config.argparsing import Parser
import sqlalchemy


@pytest.hookimpl()
def pytest_addoption(parser: Parser) -> None:
    """Registers argparse-style options for Compara's unit testing."""
    # Add the Compara unitary test parameters to pytest parser
    group = parser.getgroup("compara unit testing")
    group.addoption('--server', action='store', metavar='URL', dest='server', required=True,
                    help="URL to the server where to create the test database(s).")
    group.addoption('--keep-data', action='store_true', dest='keep_data',
                    help="Do not remove test databases/temp directories. Default: False")


def pytest_configure(config: Config) -> None:
    """Adds global variables and configuration attributes required by most tests."""
    # Load server information
    server_url = sqlalchemy.engine.url.make_url(config.getoption('server'))
    # If password starts with '$', treat it as an environment variable that needs to be resolved
    if server_url.password and server_url.password.startswith('$'):
        server_url.password = os.environ[server_url.password[1:]]
        config.option.server = str(server_url)
