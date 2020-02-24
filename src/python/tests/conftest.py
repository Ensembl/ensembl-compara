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

# import os

import pytest
from _pytest.config.argparsing import Parser


@pytest.hookimpl()
def pytest_addoption(parser: Parser) -> None:
    """Register argparse-style options for Compara's unitary testing."""
    group = parser.getgroup("compara unitary test")
    group.addoption('--server', action='store', metavar='URL', dest='server',
                    # default=f'mysql://ensadmin:{os.environ["ENSADMIN_PSW"]}@mysql-ens-compara-prod-1:4485/',
                    help="URL to the server where to create the test database(s)")
