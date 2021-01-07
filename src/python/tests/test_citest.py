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
"""Unit testing of :mod:`citest` module.

The unit testing is divided into one test class per submodule/class found in this module, and one test method
per public function/class method.

Typical usage example::

    $ pytest test_citest.py

"""

from contextlib import ExitStack as does_not_raise
from typing import ContextManager, Dict

import pytest
from pytest import raises
from _pytest.fixtures import FixtureRequest

from ensembl.compara.citest import CITestDBItem, CITestDBContentError, CITestDBGroupingError, \
    CITestDBNumRowsError, CITestFilesItem, CITestFilesContentError, CITestFilesSizeError, CITestFilesTreeError
from ensembl.compara.filesys import DirCmp


@pytest.mark.parametrize("multi_dbs", [[{'src': 'citest/reference'}, {'src': 'citest/target'}]],
                         indirect=True)
class TestCITestDBItem:
    """Tests CITest's :class:`CITestDBItem` class.

    Attributes:
        db_item (CITestDBItem): Set of integration tests to compare a table in two (analogous) databases.

    """

    db_item = None  # type: CITestDBItem

    # autouse=True makes this fixture be executed before any test_* method of this class, and scope='class' to
    # execute it only once per class parametrization
    @pytest.fixture(scope='class', autouse=True)
    def setup(self, request: FixtureRequest, multi_dbs: Dict) -> None:
        """Loads the required fixtures and values as class attributes.

        Args:
            request: Access to the requesting test context.
            multi_dbs: Dictionary of unit test databases (fixture).

        """
        # Use type(self) instead of self as a workaround to @classmethod decorator (unsupported by pytest and
        # required when scope is set to "class" <https://github.com/pytest-dev/pytest/issues/3778>)
        type(self).db_item = CITestDBItem('', request.session, multi_dbs['reference'].dbc,
                                          multi_dbs['target'].dbc, 'main_table', {})

    def test_missing_test(self):
        """Tests CITestDBItem's error handling if an unknown test is passed."""
        self.db_item.name = 'dummy'
        with raises(SyntaxError):
            self.db_item.runtest()

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
    )
    def test_num_rows_test(self, kwargs: Dict, expectation: ContextManager) -> None:
        """Tests :meth:`CITestDBItem.test_num_rows()` method.

        Args:
            kwargs: Named arguments to be passed to the method.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.ExitStack` if no exception is expected.

        """
        with expectation:
            self.db_item.test_num_rows(**kwargs)

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
    )
    def test_content_test(self, kwargs: Dict, expectation: ContextManager) -> None:
        """Tests :meth:`CITestDBItem.test_content()` method.

        Args:
            kwargs: Named arguments to be passed to the method.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.ExitStack` if no exception is expected.

        """
        with expectation:
            self.db_item.test_content(**kwargs)


@pytest.mark.parametrize("dir_cmp", [{'ref': 'citest/reference', 'target': 'citest/target'}], indirect=True)
class TestCITestFilesItem:
    """Tests CITest's :class:`CITestFilesItem` class.

    Attributes:
        files_item (CITestFilesItem): Set of integration tests to compare two (analogous) files (or
            directories).

    """

    files_item = None  # type: CITestFilesItem

    # autouse=True makes this fixture be executed before any test_* method of this class, and scope='class' to
    # execute it only once per class parametrization
    @pytest.fixture(scope='class', autouse=True)
    def setup(self, request: FixtureRequest, dir_cmp: DirCmp) -> None:
        """Loads the required fixtures and values as class attributes.

        Args:
            request: Access to the requesting test context.
            dir_cmp: Directory tree comparison (fixture).

        """
        # Use type(self) instead of self as a workaround to @classmethod decorator (unsupported by pytest and
        # required when scope is set to "class" <https://github.com/pytest-dev/pytest/issues/3778>)
        type(self).files_item = CITestFilesItem('', request.session, dir_cmp, {})

    def test_missing(self):
        """Tests CITestFilesItem's error handling if an unknown test is passed."""
        self.files_item.name = 'dummy'
        with raises(SyntaxError):
            self.files_item.runtest()

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
    )
    def test_size_test(self, kwargs: Dict, expectation: ContextManager) -> None:
        """Tests :meth:`CITestFilesItem.test_size()` method.

        Args:
            kwargs: Named arguments to be passed to the method.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.ExitStack` if no exception is expected.

        """
        with expectation:
            self.files_item.test_size(**kwargs)

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
    )
    def test_content_test(self, kwargs: Dict, expectation: ContextManager) -> None:
        """Tests :meth:`CITestFilesItem.test_content()` method.

        Args:
            kwargs: Named arguments to be passed to the method.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.ExitStack` if no exception is expected.

        """
        with expectation:
            self.files_item.test_content(**kwargs)
