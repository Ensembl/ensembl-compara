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
# Disable redefined-outer-name rule in pylint to avoid warning due to how pytest fixtures work
# pylint: disable=redefined-outer-name

import os
from pathlib import Path
import shutil
import time
from typing import Any, Dict, Generator, Optional

import pytest
from _pytest.config import Config
from _pytest.config.argparsing import Parser
from _pytest.fixtures import FixtureRequest
from _pytest.tmpdir import TempPathFactory
import sqlalchemy

from ensembl.compara.db import UnitTestDB
from ensembl.compara.filesys import DirCmp, PathLike


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
    pytest.files_dir = Path(__file__).parent / 'flatfiles'
    pytest.get_param_repr = get_param_repr


@pytest.fixture(name='db_factory', scope='session')
def db_factory_(request: FixtureRequest) -> Generator:
    """Yields a unit test database (:class:`UnitTestDB`) factory."""
    created = {}  # type: Dict[str, UnitTestDB]
    server_url = request.config.getoption('server')
    def db_factory(src: PathLike, name: Optional[str] = None) -> UnitTestDB:
        """Returns a :class:`UnitTestDB` object for the newly created unit test database `name` from `src`.

        Args:
            src: Relative directory path where the test database schema and content files are located. The
                starting directory is ``ensembl-compara/src/python/tests/databases``.
            name: Name to give to the new database (it will be prefixed by the username).

        """
        return created.setdefault(str(src), UnitTestDB(server_url, pytest.dbs_dir / src, name))
    yield db_factory
    # Drop the unit test databases unless the user has requested to keep them
    if not request.config.getoption('keep_data'):
        for test_db in created.values():
            test_db.drop()


@pytest.fixture(scope='session')
def tmp_dir(request: FixtureRequest, tmp_path_factory: TempPathFactory) -> Generator:
    """Yields a :class:`Path` object pointing to a newly created temporary directory."""
    tmpdir = tmp_path_factory.mktemp(request.node.name)
    yield tmpdir
    # Delete the temporary directory unless the user has requested to keep it
    if not request.config.getoption("keep_data"):
        shutil.rmtree(tmpdir)


@pytest.fixture(name='dir_cmp_factory', scope='session')
def dir_cmp_factory_(tmp_dir: Path) -> Generator:
    """Yields a directory tree comparison (:class:`DirCmp`) factory."""
    created = {}  # type: Dict[str, DirCmp]
    def dir_cmp_factory(path: PathLike) -> DirCmp:
        """Returns a :class:`DirCmp` object comparing reference and target directory trees in `path`.

        Args:
            path: Path to root folder that contain ``reference`` and ``target`` directories. If a relative
                path is provided, it will be assummed it is inside ``flatfiles`` folder.

        """
        if str(path) in created:
            return created[str(path)]
        # Get the source and temporary absolute paths for reference and target tree directories
        root = Path(path)
        ref_src = root / 'reference' if root.is_absolute() else pytest.files_dir / root / 'reference'
        ref_tmp = tmp_dir / root.name / 'reference'
        target_src = root / 'target' if root.is_absolute() else pytest.files_dir / root / 'target'
        target_tmp = tmp_dir / root.name / 'target'
        # Copy directory trees ignoring file metadata
        shutil.copytree(ref_src, ref_tmp, copy_function=shutil.copy)
        # Sleep one second to ensure the timestamp differs between reference and target files
        time.sleep(1)
        shutil.copytree(target_src, target_tmp, copy_function=shutil.copy)
        return created.setdefault(str(path), DirCmp(ref_tmp, target_tmp))
    yield dir_cmp_factory


def get_param_repr(arg: Any) -> Optional[str]:
    """Returns a string representation of `arg` if it is a dictionary, list or Path, `None` otherwise.

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
        return '[' + ', '.join(str(x) for x in arg) + ']'
    if isinstance(arg, Path):
        return str(arg)
    return None
