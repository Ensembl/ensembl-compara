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

from pathlib import Path
from typing import Callable, Dict

import pytest
from _pytest.fixtures import FixtureRequest

from ensembl.compara.citest import CITestDBItem, CITestDBContentError, CITestDBGroupingError, \
    CITestDBNumRowsError, CITestFilesItem, CITestFilesContentError, CITestFilesSizeError, CITestFilesTreeError


@pytest.fixture(scope="module")
def db_item(request: FixtureRequest, db_factory: Callable) -> CITestDBItem:
    """Returns a :class:`CITestDBItem` object to compare table ``main_table`` in reference and target unit
    test databases.

    Args:
        db_factory: Unit test database (:class:`UnitTestDB`) factory.

    """
    ref_db = db_factory(Path('citest', 'reference'), 'citest_reference')
    target_db = db_factory(Path('citest', 'target'), 'citest_target')
    return CITestDBItem('', request.session, ref_db.dbc, target_db.dbc, 'main_table', {})


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
        "kwargs, exception",
        [
            ({}, None),
            ({'group_by': 'grp'}, CITestDBNumRowsError),
            ({'variation': 0.5, 'group_by': 'grp'}, None),
            ({'group_by': ['grp', 'value']}, CITestDBGroupingError),
            ({'filter_by': 'value < 30'}, None),
            ({'filter_by': ['value < 30', 'grp = "grp2"']}, CITestDBNumRowsError),
            ({'variation': 0.25, 'filter_by': ['value < 30', 'grp = "grp2"']}, None),
            ({'group_by': 'grp', 'filter_by': 'value < 24'}, None),
        ],
        ids=pytest.get_param_repr
    )
    def test_num_rows_test(self, db_item: CITestDBItem, kwargs: Dict, exception: Exception) -> None:
        """Tests CITest's :meth:`CITestDBItem.test_num_rows()` method.

        Args:
            db_item: CITest object to compare a table in reference and target unit test databases.
            kwargs: Named arguments to be passed to the method.
            exception: If `None`, this test will pass if no exception is raised. If an exception is given,
                the test will pass only if that specific exception is raised.

        """
        if not exception:
            db_item.test_num_rows(**kwargs)
        else:
            with pytest.raises(exception):
                db_item.test_num_rows(**kwargs)

    @pytest.mark.parametrize(
        "kwargs, exception",
        [
            ({}, CITestDBContentError),
            ({'columns': 'value'}, None),
            ({'columns': ['value', 'comment']}, CITestDBContentError),
            ({'ignore_columns': 'grp'}, CITestDBContentError),
            ({'ignore_columns': ['id', 'grp', 'comment']}, None),
            ({'columns': 'value', 'ignore_columns': 'grp'}, TypeError),
            ({'filter_by': 'grp = "grp2"'}, CITestDBNumRowsError),
            ({'filter_by': ['value < 23', 'comment = "Second group"']}, None),
            ({'columns': 'grp', 'filter_by': 'grp = "grp3"'}, CITestDBNumRowsError),
            ({'ignore_columns': 'id', 'filter_by': 'value != 24'}, None),
        ],
        ids=pytest.get_param_repr
    )
    def test_content_test(self, db_item: CITestDBItem, kwargs: Dict, exception: Exception) -> None:
        """Tests CITest's :meth:`CITestDBItem.test_content()` method.

        Args:
            db_item: CITest object to compare a table in reference and target unit test databases.
            kwargs: Named arguments to be passed to the method.
            exception: If `None`, this test will pass if no exception is raised. If an exception is given,
                the test will pass only if that specific exception is raised.

        """
        if not exception:
            db_item.test_content(**kwargs)
        else:
            with pytest.raises(exception):
                db_item.test_content(**kwargs)


class TestCITestFilesItem:
    """Tests CITest's :class:`CITestFilesItem` class."""

    @pytest.mark.parametrize(
        "kwargs, exception",
        [
            ({}, CITestFilesSizeError),
            ({'variation': 1.0}, CITestFilesTreeError),
            ({'patterns': 'c*'}, None),
            ({'patterns': ['a*', 'c*']}, CITestFilesSizeError),
            ({'paths': '1'}, CITestFilesSizeError),
            ({'paths': ['0', '2']}, CITestFilesSizeError),
            ({'patterns': 'c*', 'paths': '1'}, None),
            ({'variation': 1.0, 'patterns': 'b*', 'paths': '1'}, None),
        ],
        ids=pytest.get_param_repr
    )
    def test_size_test(self, files_item: CITestFilesItem, kwargs: Dict, exception: Exception) -> None:
        """Tests CITest's :meth:`CITestFilesItem.test_size()` method.

        Args:
            files_item: CITest object to compare reference and target test directory trees.
            kwargs: Named arguments to be passed to the method.
            exception: If `None`, this test will pass if no exception is raised. If an exception is given,
                the test will pass only if that specific exception is raised.

        """
        if not exception:
            files_item.test_size(**kwargs)
        else:
            with pytest.raises(exception):
                files_item.test_size(**kwargs)

    @pytest.mark.parametrize(
        "kwargs, exception",
        [
            ({}, CITestFilesContentError),
            ({'patterns': 'a*'}, CITestFilesTreeError),
            ({'patterns': ['a*', 'c*']}, CITestFilesContentError),
            ({'paths': '0'}, CITestFilesTreeError),
            ({'paths': ['0', '2']}, CITestFilesContentError),
            ({'patterns': 'a*', 'paths': '0'}, None),
        ],
        ids=pytest.get_param_repr
    )
    def test_content_test(self, files_item: CITestFilesItem, kwargs: Dict, exception: Exception) -> None:
        """Tests CITest's :meth:`CITestFilesItem.test_content()` method.

        Args:
            files_item: CITest object to compare reference and target test directory trees.
            kwargs: Named arguments to be passed to the method.
            exception: If `None`, this test will pass if no exception is raised. If an exception is given,
                the test will pass only if that specific exception is raised.

        """
        if not exception:
            files_item.test_content(**kwargs)
        else:
            with pytest.raises(exception):
                files_item.test_content(**kwargs)
