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
"""Unit testing of `taxon_selector.py` script.

Typical usage example::

    $ pytest test_taxon_selector.py

"""

from contextlib import nullcontext as does_not_raise
from typing import ContextManager

import pytest
from pytest import raises

from sqlalchemy.orm.exc import NoResultFound

from ensembl.database import UnitTestDB
from ensembl.compara.utils.taxonomy import (
    collect_taxonomys_from_path,
    match_taxon_to_reference,
    filter_real_taxon,
    fetch_scientific_name
)


@pytest.mark.parametrize("db", [{"src": "ncbi_db"}], indirect=True)
class TestTaxonomySelection:
    """Tests functions `~ensembl_compara.taxonomy.taxon_selector` in taxon_selector.py

    Attributes:
        dbc (DBConnection): Database connection to the unit test database.
        dir (pytest.files_dir): Test files directory.

    """

    dbc = None # type: UnitTestDB
    dir = None

    @pytest.fixture(scope="class", autouse=True)
    def setup(self, db: UnitTestDB) -> None:
        """Loads the required fixtures and values as class attributes.

        Args:
            db: Generator of unit test database (fixture).
        """
        type(self).dbc = db.dbc
        # pylint: disable=no-member # type: ignore[attr-defined]
        type(self).dir = pytest.files_dir

    @pytest.mark.parametrize(
        "subdir, exp_out, expectation",
        [
            ("ref_taxa", ["mammalia", "vertebrata"], does_not_raise()),
            ("cake", [], raises(FileNotFoundError)),
            ("", [], does_not_raise())
        ]
    )
    def test_collect_taxonomys_from_path(
        self, subdir: str, exp_out: list, expectation: ContextManager
    ) -> None:
        """Tests :func:`collect_taxonomys_from_path()`

        Args:
            subdir: Test directory with subdirectories named by existing taxa
            exp_out: Test directory with subdirectories named by random non-taxa
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.
        """
        dirpath = self.dir / subdir
        with self.dbc.session_scope() as session:
            with expectation:
                result = collect_taxonomys_from_path(session, str(dirpath))
                assert result == exp_out

    @pytest.mark.parametrize(
        "species, taxon_list, exp_out, expectation",
        [
            ("Canis lupus", ["vertebrata", "mammalia", "eukaryota"], "mammalia", does_not_raise()),
            ("Gallus gallus", ["vertebrata", "mammalia", "eukaryota"], "vertebrata", does_not_raise()),
            ("Canis lupus", ["cake", "chocolate", "bananna"], "default", does_not_raise()),
            ("Banana cake", ["cake", "chocolate", "bananna"], "", raises(NoResultFound))
        ]
    )
    def test_match_taxon_to_reference(
        self, species: str, taxon_list: list, exp_out: str, expectation: ContextManager
    ) -> None:
        """Tests :func:`match_taxon_to_reference()`

        Args:
            species: A leaf taxon name
            taxon_list: A list of taxon clades
            exp_out: A member of the taxon_list
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.
        """
        with self.dbc.session_scope() as session:
            with expectation:
                result = match_taxon_to_reference(session, species, taxon_list)
                assert result == exp_out

    @pytest.mark.parametrize(
        "species, exp_out, expectation",
        [
            ("Canis lupus", "Canis lupus", does_not_raise()),
            ("Custard Cream", None, does_not_raise())
        ]
    )
    def test_filter_real_taxon(self, species: str, exp_out: str, expectation: ContextManager) -> None:
        """Tests :func:`filter_real_taxon()`

        Args:
            species: A real taxon name
            exp_out: Same as taxon name
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.
        """
        with self.dbc.session_scope() as session:
            with expectation:
                result = filter_real_taxon(session, species)
                assert result == exp_out

    @pytest.mark.parametrize(
        "taxon_id, exp_out, expectation",
        [
            (40674, "Mammalia", does_not_raise()),
            (1234, "Mammalia", raises(NoResultFound))
        ]
    )
    def test_fetch_scientific_name(
        self, taxon_id: int, exp_out: str, expectation: ContextManager
    ) -> None:
        """Tests :func:`fetch_scientific_name()`

        Args:
            taxon_id: A real taxon_id
            exp_out: Matching scientific taxon name to `taxon_id`
            expectation: Raises NoResultFound()
        """
        with self.dbc.session_scope() as session:
            with expectation:
                result = fetch_scientific_name(session, taxon_id)
                assert result == exp_out
