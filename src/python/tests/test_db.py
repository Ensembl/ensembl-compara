# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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
"""Unit testing of :mod:`db` module.

The unit testing is divided into one test class per submodule/class found in this module, and one test method
per public function/class method.

Typical usage example::

    $ pytest test_db.py

"""

from contextlib import ExitStack as does_not_raise
import os
from pathlib import Path
from typing import ContextManager, Dict

import pytest
from pytest import param, raises
from _pytest.fixtures import FixtureRequest
from sqlalchemy.engine.url import make_url
from sqlalchemy.exc import IntegrityError, OperationalError, ProgrammingError
from sqlalchemy.ext.automap import automap_base

from ensembl.compara.db import DBConnection, UnitTestDB


class TestUnitTestDB:
    """Tests :class:`UnitTestDB` class.

    Attributes:
        dbs (dict): Dictionary of :class:`UnitTestDB` objects with the database name as key.

    """

    dbs = {}  # type: Dict[str, UnitTestDB]

    @pytest.mark.parametrize(
        "src, name, expectation",
        [
            (Path('mock_dir'), None, raises(FileNotFoundError)),
            (Path('citest'), None, raises(FileNotFoundError)),
            param(Path('citest', 'reference'), None, does_not_raise(),
                  marks=pytest.mark.dependency(name='init_ref', scope='class')),
            param(Path('citest', 'reference'), 'renamed', does_not_raise(),
                  marks=pytest.mark.dependency(name='init_renamed', scope='class')),
        ],
    )
    def test_init(self, request: FixtureRequest, src: Path, name: str, expectation: ContextManager) -> None:
        """Tests that the object :class:`UnitTestDB` is initialised correctly.

        See :class:`UnitTestDB` for a detailed description of `src` (i.e. `dump_dir`) and `name` parameters.

        Args:
            request: Access to the requesting test context.
            src: Directory path where the test database schema and content files are located. If a relative
                path is provided, the root folder will be ``src/python/tests/databases``.
            name: Name to give to the new database.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.ExitStack` if no exception is expected.

        """
        with expectation:
            server_url = request.config.getoption('server')
            src_path = src if src.is_absolute() else pytest.dbs_dir / src
            db_key = name if name else src.name
            self.dbs[db_key] = UnitTestDB(server_url, src_path, name)
            # Check that the database has been created correctly
            assert self.dbs[db_key], "UnitTestDB should not be empty"
            assert self.dbs[db_key].dbc, "UnitTestDB's database connection should not be empty"
            # Check that the database has been loaded correctly from the dump files
            result = self.dbs[db_key].dbc.execute("SELECT * FROM main_table")
            assert len(result.fetchall()) == 10, "Unexpected number of rows found in 'main_table' table"

    @pytest.mark.parametrize(
        "db_key",
        [
            param('reference', marks=pytest.mark.dependency(depends=['init_ref'], scope='class')),
            param('renamed', marks=pytest.mark.dependency(depends=['init_renamed'], scope='class')),
        ],
    )
    def test_drop(self, db_key: str) -> None:
        """Tests that the previously created object :class:`UnitTestDB` is dropped correctly.

        Args:
            db_key: Key assigned to the UnitTestDB created in :meth:`TestUnitTestDB.test_init()`.

        """
        self.dbs[db_key].drop()
        if self.dbs[db_key].dbc.dialect == 'sqlite':
            # For SQLite databases, just check if the database file still exists
            assert not Path(self.dbs[db_key].dbc.db_name).exists(), "The database file has not been deleted"
        else:
            with raises(OperationalError, match=r'Unknown database'):
                self.dbs[db_key].dbc.execute("SELECT * FROM main_table")


@pytest.mark.parametrize("database", [{'src': 'master'}], indirect=True)
class TestDBConnection:
    """Tests :class:`DBConnection` class.

    Attributes:
        dbc (DBConnection): Database connection to the unit test database.
        server (str): Server url where the unit test database is hosted.

    """

    dbc = None  # type: DBConnection
    server = None  # type: str

    # autouse=True makes this fixture be executed before any test_* method of this class, and scope='class' to
    # execute it only once per class parametrization
    @pytest.fixture(scope='class', autouse=True)
    def setup(self, request: FixtureRequest, database: UnitTestDB) -> None:
        """Loads the required fixtures and values as class attributes.

        Args:
            request: Access to the requesting test context.
            database: Unit test database (fixture).

        """
        # Use type(self) instead of self as a workaround to @classmethod decorator (unsupported by pytest and
        # required when scope is set to "class" <https://github.com/pytest-dev/pytest/issues/3778>)
        type(self).dbc = database.dbc
        type(self).server = request.config.getoption('server')

    @pytest.mark.dependency(name='test_init', scope='class')
    def test_init(self) -> None:
        """Tests that the object :class:`DBConnection` is initialised correctly."""
        assert self.dbc, "DBConnection object should not be empty"

    @pytest.mark.dependency(name='test_db_name', depends=['test_init'], scope='class')
    def test_db_name(self) -> None:
        """Tests :meth:`DBConnection.db_name` property."""
        assert self.dbc.db_name == f"{os.environ['USER']}_master"

    @pytest.mark.dependency(depends=['test_init', 'test_db_name'], scope='class')
    def test_url(self) -> None:
        """Tests :meth:`DBConnection.url` property."""
        assert self.dbc.url == self.server + self.dbc.db_name

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_host(self) -> None:
        """Tests :meth:`DBConnection.host` property."""
        assert self.dbc.host == make_url(self.server).host

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_dialect(self) -> None:
        """Tests :meth:`DBConnection.dialect` property."""
        assert self.dbc.dialect == make_url(self.server).drivername

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_tables(self) -> None:
        """Tests :meth:`DBConnection.tables` property."""
        tables = {
            'CAFE_gene_family', 'CAFE_species_gene', 'conservation_score', 'constrained_element', 'dnafrag',
            'dnafrag_region', 'exon_boundaries', 'external_db', 'family', 'family_member', 'gene_align',
            'gene_align_member', 'gene_member', 'gene_member_hom_stats', 'gene_member_qc', 'gene_tree_node',
            'gene_tree_node_attr', 'gene_tree_node_tag', 'gene_tree_object_store', 'gene_tree_root',
            'gene_tree_root_attr', 'gene_tree_root_tag', 'genome_db', 'genomic_align', 'genomic_align_block',
            'genomic_align_tree', 'hmm_annot', 'hmm_curated_annot', 'hmm_profile', 'homology', 'member_xref',
            'homology_member', 'mapping_session', 'meta', 'method_link', 'method_link_species_set',
            'method_link_species_set_attr', 'method_link_species_set_tag', 'ncbi_taxa_name', 'ncbi_taxa_node',
            'other_member_sequence', 'peptide_align_feature', 'seq_member_projection', 'stable_id_history',
            'seq_member_projection_stable_id', 'sequence', 'species_set', 'species_set_header', 'seq_member',
            'species_set_tag', 'species_tree_node', 'species_tree_node_attr', 'species_tree_node_tag',
            'species_tree_root', 'synteny_region'
        }
        assert set(self.dbc.tables.keys()) == tables

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_get_primary_key_columns(self) -> None:
        """Tests :meth:`DBConnection.get_primary_key_columns()` method."""
        table = 'species_set'
        assert set(self.dbc.get_primary_key_columns(table)) == {'species_set_id', 'genome_db_id'}, \
            f"Unexpected set of primary key columns found in table '{table}'"

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_get_columns(self) -> None:
        """Tests :meth:`DBConnection.get_columns()` method."""
        table = 'method_link'
        assert set(self.dbc.get_columns(table)) == {'method_link_id', 'type', 'class', 'display_name'}, \
            f"Unexpected set of columns found in table '{table}'"

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_schema_type(self) -> None:
        """Tests :meth:`DBConnection.schema_type` property."""
        assert self.dbc.schema_type == 'compara', "Unexpected schema type found in database's 'meta' table"

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_schema_version(self) -> None:
        """Tests :meth:`DBConnection.schema_version` property."""
        assert self.dbc.schema_version == 99, "Unexpected schema version found in database's 'meta' table"

    @pytest.mark.dependency(name='test_connect', depends=['test_init'], scope='class')
    def test_connect(self) -> None:
        """Tests :meth:`DBConnection.connect()` method."""
        connection = self.dbc.connect()
        assert connection, "Connection object should not be empty"
        result = connection.execute("SELECT * FROM species_set_tag")
        assert len(result.fetchall()) == 2, "Unexpected number of rows found in 'species_set_tag' table"
        connection.close()

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_begin(self) -> None:
        """Tests :meth:`DBConnection.begin()` method."""
        with self.dbc.begin() as connection:
            assert connection, "Connection object should not be empty"
            result = connection.execute("SELECT * FROM species_set_tag")
            assert len(result.fetchall()) == 2, "Unexpected number of rows found in 'species_set_tag' table"

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    def test_dispose(self) -> None:
        """Tests :meth:`DBConnection.dispose()` method."""
        self.dbc.dispose()
        num_conn = self.dbc._engine.pool.checkedin()  # pylint: disable=protected-access
        assert num_conn == 0, "A new pool should have 0 checked-in connections"

    @pytest.mark.parametrize(
        "query, nrows, expectation",
        [
            param("SELECT * FROM method_link_species_set_tag", 4, does_not_raise(),
                  marks=pytest.mark.dependency(name='test_exec1', depends=['test_init'], scope='class')),
            param("SELECT * FROM my_table", 0, raises(ProgrammingError, match=r"my_table.* doesn't exist"),
                  marks=pytest.mark.dependency(name='test_exec2', depends=['test_init'], scope='class')),
        ],
    )
    def test_execute(self, query: str, nrows: int, expectation: ContextManager) -> None:
        """Tests :meth:`DBConnection.execute()` method.

        Args:
            query: SQL query.
            nrows: Number of rows expected to be returned from the query.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.ExitStack` if no exception is expected.

        """
        with expectation:
            result = self.dbc.execute(query)
            assert len(result.fetchall()) == nrows, "Unexpected number of rows returned"

    @pytest.mark.dependency(depends=['test_init', 'test_connect', 'test_exec1', 'test_exec2'], scope='class')
    @pytest.mark.parametrize(
        "mlss_id, tag1, tag2, before, after",
        [
            (4, {'tag': 'ref', 'value': 'human'}, {'tag': 'non_ref1', 'value': 'chicken'}, 0, 2),
            (4, {'tag': 'non_ref2', 'value': 'tick'}, {'tag': 'non_ref2', 'value': 'mouse'}, 2, 2),
        ],
    )
    def test_session_scope(self, mlss_id: int, tag1: Dict[str, str], tag2: Dict[str, str], before: int,
                           after: int) -> None:
        """Tests :meth:`DBConnection.session_scope()` method.

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

    @pytest.mark.dependency(depends=['test_init', 'test_connect', 'test_exec1', 'test_exec2'], scope='class')
    def test_test_session_scope(self) -> None:
        """Tests :meth:`DBConnection.test_session_scope()` method."""
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
