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
# Disable all the redefined-outer-name violations due to how pytest fixtures work
# pylint: disable=redefined-outer-name

from contextlib import ExitStack as does_not_raise
import os
from pathlib import Path
from typing import Callable, ContextManager, Dict

import pytest
from pytest import raises
from _pytest.fixtures import FixtureRequest
from sqlalchemy.engine.url import make_url
from sqlalchemy.exc import IntegrityError, OperationalError, ProgrammingError
from sqlalchemy.ext.automap import automap_base

from ensembl.compara.db import DBConnection, UnitTestDB


class TestUnitTestDB:
    """Tests :class:`UnitTestDB` class."""

    dbs_created = {}  # type: Dict[str, UnitTestDB]

    @pytest.mark.parametrize(
        "src, name, expectation",
        [
            (Path('citest'), None, raises(FileNotFoundError)),
            pytest.param(Path('citest', 'reference'), None, does_not_raise(),
                         marks=pytest.mark.dependency(name="reference")),
            pytest.param(Path('citest', 'reference'), 'renamed', does_not_raise(),
                         marks=pytest.mark.dependency(name="renamed")),
        ],
    )
    def test_init(self, request: FixtureRequest, src: Path, name: str, expectation: ContextManager) -> None:
        """Tests that the object :class:`UnitTestDB` is initialised correctly.

        Args:
            src: Relative directory path where the test database schema and content files are located,
                starting from ``ensembl-compara/src/python/tests/databases``.
            name: Name to give to the new database (it will be prefixed by the username).
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`contextlib.nullcontext` if no exception is expected.

        """
        server_url = request.config.getoption('server')
        with expectation:
            db_name = name if name else src.name
            self.dbs_created[db_name] = UnitTestDB(server_url, pytest.dbs_dir / src, name)
            # Check that the database has been created correctly
            assert self.dbs_created[db_name], "UnitTestDB should not be empty"
            assert self.dbs_created[db_name].dbc, "UnitTestDB's database connection should not be empty"
            database_name = os.environ['USER'] + '_' + db_name
            if self.dbs_created[db_name].dbc.dialect == 'sqlite':
                # Need to add the path to the database and ".db" extension
                database_name = make_url(server_url).database + '/' + database_name + '.db'
            assert self.dbs_created[db_name].dbc.db_name == database_name, \
                f"Expected database name to be '{database_name}'"
            # Check that the database has been loaded correctly from the dump files
            result = self.dbs_created[db_name].dbc.execute("SELECT * FROM main_table")
            assert len(result.fetchall()) == 10, "Unexpected number of rows found in 'main_table' table"

    @pytest.mark.parametrize(
        "db_name",
        [
            pytest.param('reference', marks=pytest.mark.dependency(depends=['reference'], scope='class')),
            pytest.param('renamed', marks=pytest.mark.dependency(depends=['renamed'], scope='class')),
        ],
    )
    def test_drop(self, db_name: str) -> None:
        """Tests that the previously created object :class:`UnitTestDB` is dropped correctly.

        Args:
            db_name: Key assigned to the UnitTestDB created in :meth:`TestUnitTestDB.test_init()`.

        """
        self.dbs_created[db_name].drop()
        if self.dbs_created[db_name].dbc.dialect == 'sqlite':
            # For SQLite databases, just check if the database file still exists
            assert not Path(self.dbs_created[db_name].dbc.db_name).exists(), \
                "The database file has not been deleted"
        else:
            with raises(OperationalError, match=r'Unknown database'):
                self.dbs_created[db_name].dbc.execute("SELECT * FROM main_table")


@pytest.fixture(scope='class')
def test_dbc(request: FixtureRequest, db_factory: Callable) -> None:
    """Assigns a :class:`DBConnection` object to a pytest class attribute.

    The object connects to an example of a Compara master database.

    """
    test_db = db_factory('master', 'test_master')
    request.cls.dbc = test_db.dbc


@pytest.mark.usefixtures('test_dbc')
class TestDBConnection:
    """Tests :class:`DBConnection` class."""

    dbc = None  # type: DBConnection

    @pytest.mark.dependency()
    def test_init(self) -> None:
        """Tests that the object :class:`DBConnection` is initialised correctly."""
        assert self.dbc, "DBConnection object should not be empty"

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_url(self, request: FixtureRequest) -> None:
        """Tests DBConnection's :meth:`DBConnection.url` property."""
        server_url = request.config.getoption('server')
        assert self.dbc.url == f"{server_url}{os.environ['USER']}_test_master"

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_db_name(self) -> None:
        """Tests DBConnection's :meth:`DBConnection.db_name` property."""
        assert self.dbc.db_name == f"{os.environ['USER']}_test_master"

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_host(self, request: FixtureRequest) -> None:
        """Tests DBConnection's :meth:`DBConnection.host` property."""
        server_url = request.config.getoption('server')
        assert self.dbc.host == make_url(server_url).host

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_dialect(self, request: FixtureRequest) -> None:
        """Tests DBConnection's :meth:`DBConnection.dialect` property."""
        server_url = request.config.getoption('server')
        assert self.dbc.dialect == make_url(server_url).drivername

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_tables(self) -> None:
        """Tests DBConnection's :meth:`DBConnection.tables` property."""
        tables = {file.stem for file in pytest.dbs_dir.glob('master/*.txt')}
        assert set(self.dbc.tables.keys()) == tables  # type: ignore

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_get_primary_key_columns(self) -> None:
        """Tests DBConnection's :meth:`DBConnection.get_primary_key_columns()` method."""
        table = 'species_set'
        assert set(self.dbc.get_primary_key_columns(table)) == {'species_set_id', 'genome_db_id'}, \
            f"Unexpected set of primary key columns found in table '{table}'"

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_get_columns(self) -> None:
        """Tests DBConnection's :meth:`DBConnection.get_columns()` method."""
        table = 'method_link'
        assert set(self.dbc.get_columns(table)) == {'method_link_id', 'type', 'class', 'display_name'}, \
            f"Unexpected set of columns found in table '{table}'"

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_schema_type(self) -> None:
        """Tests DBConnection's :meth:`DBConnection.schema_type` property."""
        assert self.dbc.schema_type == 'compara', "Unexpected schema type found in database's 'meta' table"

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_schema_version(self) -> None:
        """Tests DBConnection's :meth:`DBConnection.schema_version` property."""
        assert self.dbc.schema_version == 99, "Unexpected schema version found in database's 'meta' table"

    @pytest.mark.dependency(name='test_connect', depends=['test_init'], scope='class')
    def test_connect(self) -> None:
        """Tests DBConnection's :meth:`DBConnection.connect()` method."""
        connection = self.dbc.connect()
        assert connection, "Connection object should not be empty"
        result = connection.execute("SELECT * FROM species_set_tag")
        assert len(result.fetchall()) == 2, "Unexpected number of rows found in 'species_set_tag' table"
        connection.close()

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_begin(self) -> None:
        """Tests DBConnection's :meth:`DBConnection.begin()` method."""
        with self.dbc.begin() as connection:
            assert connection, "Connection object should not be empty"
            result = connection.execute("SELECT * FROM species_set_tag")
            assert len(result.fetchall()) == 2, "Unexpected number of rows found in 'species_set_tag' table"

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_dispose(self) -> None:
        """Tests DBConnection's :meth:`DBConnection.dispose()` method."""
        self.dbc.dispose()
        num_conn = self.dbc._engine.pool.checkedin()  # pylint: disable=protected-access
        assert num_conn == 0, "A new pool should have 0 checked-in connections"

    @pytest.mark.dependency(name='test_excute', depends=['test_init'], scope='class')
    @pytest.mark.parametrize(
        "query, nrows, expectation",
        [
            ("SELECT * FROM method_link_species_set_tag", 4, does_not_raise()),
            ("SELECT * FROM my_table", 0, raises(ProgrammingError, match=r"my_table.* doesn't exist")),
        ],
    )
    def test_execute(self, query: str, nrows: int, expectation: ContextManager) -> None:
        """Tests DBConnection's :meth:`DBConnection.execute()` method.

        Args:
            query: SQL query.
            nrows: Number of rows expected to be returned from the query.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`contextlib.nullcontext` if no exception is expected.

        """
        with expectation:
            result = self.dbc.execute(query)
            assert len(result.fetchall()) == nrows, "Unexpected number of rows returned"

    @pytest.mark.dependency(depends=['test_init', 'test_connect', 'test_excute'], scope='class')
    @pytest.mark.parametrize(
        "mlss_id, tag1, tag2, before, after",
        [
            (4, {'tag': 'ref', 'value': 'human'}, {'tag': 'non_ref1', 'value': 'chicken'}, 0, 2),
            (4, {'tag': 'non_ref2', 'value': 'tick'}, {'tag': 'non_ref2', 'value': 'mouse'}, 2, 2),
        ],
    )
    def test_session_scope(self, mlss_id: int, tag1: Dict[str, str], tag2: Dict[str, str], before: int,
                           after: int) -> None:
        """Tests DBConnection's :meth:`DBConnection.session_scope()` method.

        Args:
            mlss_id: Method link species set ID to add the tags to.
            tag1: Method link species set tag 1.
            tag2: Method link species set tag 2.
            before: Number of rows in ``method_link_species_set_tag`` for `mlss_id` before adding the tags.
            after: Number of rows in ``method_link_species_set_tag`` for `mlss_id` after adding the tags.

        """
        query = f"SELECT * FROM method_link_species_set_tag WHERE method_link_species_set_id = {mlss_id}"
        results = self.dbc.execute(query)
        assert len(results.fetchall()) == before
        # Session requires mapped classes to interact with the database
        Base = automap_base()
        Base.prepare(self.dbc.connect(), reflect=True)
        MLSSTag = Base.classes.method_link_species_set_tag
        # Ignore the IntegrityError raised when commiting the new tags as some parametrizations will force it
        try:
            with self.dbc.session_scope() as session:
                rows = [MLSSTag(method_link_species_set_id=mlss_id, **tag1),
                        MLSSTag(method_link_species_set_id=mlss_id, **tag2)]
                session.add_all(rows)
        except IntegrityError:
            pass
        results = self.dbc.execute(query)
        assert len(results.fetchall()) == after

    @pytest.mark.dependency(depends=['test_init', 'test_connect', 'test_excute'], scope='class')
    def test_test_session_scope(self) -> None:
        """Tests DBConnection's :meth:`DBConnection.test_session_scope()` method."""
        # Session requires mapped classes to interact with the database
        Base = automap_base()
        Base.prepare(self.dbc.connect(), reflect=True)
        MLSSTag = Base.classes.method_link_species_set_tag
        # Check that the tags added during the context manager are removed afterwards
        mlss_id = 5
        with self.dbc.test_session_scope() as session:
            results = session.query(MLSSTag).filter_by(method_link_species_set_id=mlss_id)
            assert not results.all(), f"MLSS ID {mlss_id} shoud not have any tags"
            rows = [MLSSTag(method_link_species_set_id=mlss_id, tag='ref', value='squid'),
                    MLSSTag(method_link_species_set_id=mlss_id, tag='non_ref', value='mouse')]
            session.add_all(rows)
            session.commit()
            results = session.query(MLSSTag).filter_by(method_link_species_set_id=mlss_id)
            assert len(results.all()) == 2, f"MLSS ID {mlss_id} should have two tags"
        results = self.dbc.execute(
            f"SELECT * FROM method_link_species_set_tag WHERE method_link_species_set_id = {mlss_id}")
        assert not results.fetchall(), f"No tags should have been added permanently to MLSS ID {mlss_id}"
