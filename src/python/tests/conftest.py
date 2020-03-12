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
import shutil
from typing import Any, Generator, Optional

import pytest
from _pytest.config import Config
from _pytest.config.argparsing import Parser
from _pytest.fixtures import FixtureRequest
from _pytest.tmpdir import TempPathFactory
import sqlalchemy

from ensembl.compara.db import UnitTestDB


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
    # Add global variables
    pytest.dbs_dir = Path(__file__).parent / 'databases'
    pytest.get_param_repr = get_param_repr


@pytest.fixture(name='db_factory', scope='session')
def db_factory_(request: FixtureRequest) -> Generator:
    """Yields a unit test database (:class:`UnitTestDB`) factory."""
    created = []
    server_url = request.config.getoption('server')
    def db_factory(src: str, name: Optional[str] = None) -> UnitTestDB:
        """Returns a :class:`UnitTestDB` object for the newly created unit test database `name` from `src`.

        Args:
            src: Relative directory path where the test database schema and content files are located. The
                starting directory is ``ensembl-compara/src/python/tests/databases``.
            name: Name to give to the new database (it will be prefixed by the username).

        """
        test_db = UnitTestDB(server_url, pytest.dbs_dir / src, name)
        created.append(test_db)
        return test_db
    yield db_factory
    # Drop the unit test databases unless the user has requested to keep them
    if not request.config.getoption('keep_data'):
        for test_db in created:
            test_db.drop()


@pytest.fixture(scope='session')
def tmp_dir(request: FixtureRequest, tmp_path_factory: TempPathFactory) -> Generator:
    """Yields a :class:`Path` object pointing to a newly created temporary directory."""
    tmpdir = tmp_path_factory.mktemp('')
    yield tmpdir
    # Delete the temporary directory unless the user has requested to keep it
    if not request.config.getoption("keep_data"):
        shutil.rmtree(tmpdir)


def get_param_repr(arg: Any) -> Optional[str]:
    """Returns a string representation of `arg` if it is a dictionary or a list, `None` otherwise.

    Note:
        `None` will tell pytest to use its default internal representation of `arg`.

    """
    if isinstance(arg, dict):
        str_repr = ''
        for key, value in arg.items():
            value_repr = get_param_repr(value)
            str_repr += f"{key}: {value_repr if value_repr else value}; "
        return '{' + str_repr[:-2] + '}'
    if isinstance(arg, list):
        return '[' + ', '.join(arg) + ']'
    return None
