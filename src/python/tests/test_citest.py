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
# Disable redefined-outer-name rule in pylint to avoid warning due to how pytest fixtures work
# pylint: disable=redefined-outer-name

from contextlib import ExitStack as does_not_raise
from pathlib import Path
from typing import Callable, ContextManager, Dict

import pytest
from pytest import raises
from _pytest.fixtures import FixtureRequest

from ensembl.compara.citest import CITestDBItem, CITestDBContentError, CITestDBGroupingError, \
    CITestDBNumRowsError, CITestFilesItem, CITestFilesContentError, CITestFilesSizeError, CITestFilesTreeError


@pytest.fixture(scope="module")
def db_item(request: FixtureRequest, multidb_factory: Callable) -> CITestDBItem:
    """Returns a :class:`CITestDBItem` object to compare table ``main_table`` in reference and target unit
    test databases.

    Args:
        multidb_factory: Multi-:class:`UnitTestDB` factory.

    """
    dbs = multidb_factory(Path('citest'))
    return CITestDBItem('', request.session, dbs['reference'].dbc, dbs['target'].dbc, 'main_table', {})


@pytest.fixture(scope="module")
def files_item(request: FixtureRequest, dir_cmp_factory: Callable) -> CITestFilesItem:
    """Returns a :class:`CITestFilesItem` object to compare ``flatfiles/citest`` reference and target
    directory trees.

    Args:
        dir_cmp_factory: Directory tree comparison (:class:`DirCmp`) factory.

    """
    dir_cmp = dir_cmp_factory('citest')
    return CITestFilesItem('', request.session, dir_cmp, {})


class TestCITestDBItem:
    """Tests CITest's :class:`CITestDBItem` class."""

    @pytest.mark.parametrize(
        "kwargs, expectation",
        [
            ({}, does_not_raise()),
            ({'group_by': 'grp'}, raises(CITestDBNumRowsError)),
            ({'variation': 0.5, 'group_by': 'grp'}, does_not_raise()),
            ({'group_by': ['grp', 'value']}, raises(CITestDBGroupingError)),
            ({'filter_by': 'value < 30'}, does_not_raise()),
            ({'filter_by': ['value < 30', 'grp = "grp2"']}, raises(CITestDBNumRowsError)),
            ({'variation': 0.25, 'filter_by': ['value < 30', 'grp = "grp2"']}, does_not_raise()),
            ({'group_by': 'grp', 'filter_by': 'value < 24'}, does_not_raise()),
        ],
        ids=pytest.get_param_repr
    )
    def test_num_rows_test(self, db_item: CITestDBItem, kwargs: Dict, expectation: ContextManager) -> None:
        """Tests CITest's :meth:`CITestDBItem.test_num_rows()` method.

        Args:
            kwargs: Named arguments to be passed to the method.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`contextlib.nullcontext` if no exception is expected.

        """
        with expectation:
            db_item.test_num_rows(**kwargs)

    @pytest.mark.parametrize(
        "kwargs, expectation",
        [
            ({}, raises(CITestDBContentError)),
            ({'columns': 'value'}, does_not_raise()),
            ({'columns': ['value', 'comment']}, raises(CITestDBContentError)),
            ({'ignore_columns': 'grp'}, raises(CITestDBContentError)),
            ({'ignore_columns': ['id', 'grp', 'comment']}, does_not_raise()),
            ({'columns': 'value', 'ignore_columns': 'grp'}, raises(TypeError)),
            ({'filter_by': 'grp = "grp2"'}, raises(CITestDBNumRowsError)),
            ({'filter_by': ['value < 23', 'comment = "Second group"']}, does_not_raise()),
            ({'columns': 'grp', 'filter_by': 'grp = "grp3"'}, raises(CITestDBNumRowsError)),
            ({'ignore_columns': 'id', 'filter_by': 'value != 24'}, does_not_raise()),
        ],
        ids=pytest.get_param_repr
    )
    def test_content_test(self, db_item: CITestDBItem, kwargs: Dict, expectation: ContextManager) -> None:
        """Tests CITest's :meth:`CITestDBItem.test_content()` method.

        Args:
            kwargs: Named arguments to be passed to the method.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`contextlib.nullcontext` if no exception is expected.

        """
        with expectation:
            db_item.test_content(**kwargs)


class TestCITestFilesItem:
    """Tests CITest's :class:`CITestFilesItem` class."""

    @pytest.mark.parametrize(
        "kwargs, expectation",
        [
            ({}, raises(CITestFilesSizeError)),
            ({'variation': 1.0}, raises(CITestFilesTreeError)),
            ({'patterns': 'c*'}, does_not_raise()),
            ({'patterns': ['a*', 'c*']}, raises(CITestFilesSizeError)),
            ({'paths': '1'}, raises(CITestFilesSizeError)),
            ({'paths': ['0', '2']}, raises(CITestFilesSizeError)),
            ({'patterns': 'c*', 'paths': '1'}, does_not_raise()),
            ({'variation': 1.0, 'patterns': 'b*', 'paths': '1'}, does_not_raise()),
        ],
        ids=pytest.get_param_repr
    )
    def test_size_test(self, files_item: CITestFilesItem, kwargs: Dict, expectation: ContextManager) -> None:
        """Tests CITest's :meth:`CITestFilesItem.test_size()` method.

        Args:
            kwargs: Named arguments to be passed to the method.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`contextlib.nullcontext` if no exception is expected.

        """
        with expectation:
            files_item.test_size(**kwargs)

    @pytest.mark.parametrize(
        "kwargs, expectation",
        [
            ({}, raises(CITestFilesContentError)),
            ({'patterns': 'a*'}, raises(CITestFilesTreeError)),
            ({'patterns': ['a*', 'c*']}, raises(CITestFilesContentError)),
            ({'paths': '0'}, raises(CITestFilesTreeError)),
            ({'paths': ['0', '2']}, raises(CITestFilesContentError)),
            ({'patterns': 'a*', 'paths': '0'}, does_not_raise()),
        ],
        ids=pytest.get_param_repr
    )
    def test_content_test(self, files_item: CITestFilesItem, kwargs: Dict, expectation: ContextManager
                         ) -> None:
        """Tests CITest's :meth:`CITestFilesItem.test_content()` method.

        Args:
            kwargs: Named arguments to be passed to the method.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`contextlib.nullcontext` if no exception is expected.

        """
        with expectation:
            files_item.test_content(**kwargs)
