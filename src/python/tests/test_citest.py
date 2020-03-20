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
import time
from typing import Callable, Dict

import pytest
from _pytest.fixtures import FixtureRequest

from ensembl.compara.citest import CITestDBItem, CITestDBContentError, CITestDBGroupingError, \
    CITestDBNumRowsError, CITestFilesItem, CITestFilesContentError, CITestFilesSizeError, CITestFilesTreeError
from ensembl.compara.filesys import DirCmp


@pytest.fixture(scope="module")
def db_item(request: FixtureRequest, db_factory: Callable) -> CITestDBItem:
    """Returns a :class:`CITestDBItem` object to compare table ``main_table`` in reference and target unit
    test databases.

    Args:
        db_factory: Unit test database (:class:`UnitTestDB`) factory.

    """
    ref_db = db_factory(Path('citest/reference'), 'citest_reference')
    target_db = db_factory(Path('citest/target'), 'citest_target')
    return CITestDBItem('', request.session, ref_db.dbc, target_db.dbc, 'main_table', {})


@pytest.fixture(scope="module")
def dir_cmp(tmp_dir: Path) -> DirCmp:
    """Returns a :class:`DirCmp` object that contains the comparison between reference and target directory
    trees.

    Reference and target test directory trees are as follows:
        reference                                   target
            ├─ 0                                        ├─ 0
            │  ├─ 0                                     │  └─ a.txt [content: "a"]
            │  │  └─ b.txt [content: "a"]               ├─ 1
            │  └─ a.txt [content: "a"]                  │  ├─ b.txt [content: "ab"]
            ├─ 1                                        │  └─ c.txt [content: "b"]
            │  ├─ b.txt [content: "a"]                  └─ 2
            │  └─ c.txt [content: "a"]                     └─ a.nw [content: "(a);"]
            └─ 2
               └─ a.nw [content: "(a);"]

    """
    def create_file(path: Path, content: str) -> None:
        """Creates the file given in `path` and writes `content` in it.

        If the parent directory of the file does not exist, it is created.

        """
        if not path.parent.exists():
            path.parent.mkdir()
        path.write_text(content)
    # Create reference and target root directories
    ref_dir = tmp_dir / 'reference'
    ref_dir.mkdir()
    target_dir = tmp_dir / 'target'
    target_dir.mkdir()
    # Create reference subdirectories/files
    create_file(ref_dir / '0' / 'a.txt', "a")
    create_file(ref_dir / '0' / '0' / 'b.txt', "a")
    create_file(ref_dir / '1' / 'b.txt', "a")
    create_file(ref_dir / '1' / 'c.txt', "a")
    create_file(ref_dir / '2' / 'a.nw', "(a);")
    # Sleep one second to ensure the timestamp differs between reference and target files
    time.sleep(1)
    # Create target subdirectories/files
    create_file(target_dir / '0' / 'a.txt', "a")
    create_file(target_dir / '1' / 'b.txt', "ab")
    create_file(target_dir / '1' / 'c.txt', "b")
    create_file(target_dir / '2' / 'a.nw', "(a);")
    return DirCmp(ref_dir, target_dir)


@pytest.fixture(scope="module")
def files_item(request: FixtureRequest, dir_cmp: DirCmp) -> CITestFilesItem:
    """Returns a :class:`CITestFilesItem` object to compare two test directory trees.

    Args:
        dir_cmp: Directory comparison object for two test directory trees.

    """
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
            ({'patterns': 'c*'}, CITestFilesTreeError),
            ({'patterns': ['a*', 'c*']}, CITestFilesTreeError),
            ({'paths': '2'}, None),
            ({'paths': ['0', '1']}, CITestFilesSizeError),
            ({'patterns': 'b*', 'paths': '1'}, CITestFilesSizeError),
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
            ({'paths': '2'}, None),
            ({'paths': ['0', '2']}, CITestFilesTreeError),
            ({'patterns': 'b*', 'paths': '2'}, None),
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
