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
"""Unit testing of :mod:`filesys` module.

The unit testing is divided into one test class per submodule/class found in this module, and one test method
per public function/class method. A base test class has been added to load the basic attributes required by
the unit test classes.

Typical usage example::

    $ pytest test_filesys.py

"""

from contextlib import ExitStack as does_not_raise
import filecmp
from pathlib import Path
from typing import ContextManager, Dict, Set

import pytest
from pytest import raises

from ensembl.compara.filesys import DirCmp, file_cmp
from ensembl.utils import StrPath


class BaseTestFilesys:
    """Base class to configure all the attributes required by the test classes of this module.

    Attributes:
        dir_cmp (DirCmp): Directory tree comparison.

    """

    dir_cmp: DirCmp = None

    # autouse=True makes this fixture be executed before any test_* method of this class, and scope='class' to
    # execute it only once per class parametrization
    @pytest.fixture(scope='class', autouse=True)
    def setup(self, dir_cmp: DirCmp) -> None:
        """Loads the required fixtures and values as class attributes.

        Args:
            dir_cmp: Directory tree comparison (fixture).

        """
        # Use type(self) instead of self as a workaround to @classmethod decorator (unsupported by pytest and
        # required when scope is set to "class" <https://github.com/pytest-dev/pytest/issues/3778>)
        type(self).dir_cmp = dir_cmp


@pytest.mark.parametrize("dir_cmp", [{'ref': 'citest/reference', 'target': 'citest/target'}], indirect=True)
class TestDirCmp(BaseTestFilesys):
    """Tests :class:`DirCmp` class."""

    @pytest.mark.dependency(name='test_init', scope='class')
    def test_init(self) -> None:
        """Tests that the object :class:`DirCmp` is initialised correctly."""
        assert "citest_reference" == self.dir_cmp.ref_path.name, "Unexpected reference root path"
        assert "citest_target" == self.dir_cmp.target_path.name, "Unexpected target root path"
        # Check the files at the root
        assert self.dir_cmp.common_files == set(), "Found unexpected files at the root of both trees"
        assert self.dir_cmp.ref_only == {'3/a.txt'}, "Expected '3/a.txt' at reference tree's root"
        assert self.dir_cmp.target_only == {'4/a.txt'}, "Expected '4/a.txt' at target tree's root"
        # Check each subdirectory
        expected = {
            1: {'common_files': {'b.txt', 'c.txt'}},
            2: {'common_files': {'a.nw', 'b.nwk'}},
        }
        for i, value in expected.items():
            key = Path(str(i))
            for attr in ['common_files', 'ref_only', 'target_only', 'subdirs']:
                if attr in value:
                    assert getattr(self.dir_cmp.subdirs[key], attr) == value[attr], \
                        f"Expected {attr} '{', '.join(value[attr])}' at '{i}/'"
                else:
                    assert not getattr(self.dir_cmp.subdirs[key], attr), \
                        f"Found unexpected {attr} elements at '{i}/'"

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    @pytest.mark.parametrize(
        "kwargs, output, expectation",
        [
            ({}, {'0/a.txt'}, does_not_raise()),
            ({'patterns': 'a*'}, {'0/a.txt'}, does_not_raise()),
            ({'patterns': ['b*', 'c*']}, set(), does_not_raise()),
            ({'paths': '3'}, None, raises(ValueError)),
            ({'paths': ['1', '2']}, set(), does_not_raise()),
            ({'patterns': 'a*', 'paths': ['1', '2']}, set(), does_not_raise()),
        ],
    )
    def test_apply_test(self, kwargs: Dict, output: Set[str], expectation: ContextManager) -> None:
        """Tests :meth:`DirCmp.apply_test()` method.

        Args:
            kwargs: Named arguments to be passed to the method.
            output: Expected file paths returned by the method.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.ExitStack` if no exception is expected.

        """
        with expectation:
            assert set(self.dir_cmp.apply_test(filecmp.cmp, **kwargs)) == output

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    @pytest.mark.parametrize(
        "kwargs, output, expectation",
        [
            ({}, {'0/a.txt', '1/b.txt', '1/c.txt', '2/a.nw', '2/b.nwk'}, does_not_raise()),
            ({'patterns': 'a*'}, {'0/a.txt', '2/a.nw'}, does_not_raise()),
            ({'patterns': ['b*', 'c*']}, {'1/b.txt', '1/c.txt', '2/b.nwk'}, does_not_raise()),
            ({'paths': '3'}, None, raises(ValueError)),
            ({'paths': ['1', '2']}, {'1/b.txt', '1/c.txt', '2/a.nw', '2/b.nwk'}, does_not_raise()),
            ({'patterns': 'a*', 'paths': ['1', '2']}, {'2/a.nw'}, does_not_raise()),
        ],
    )
    def test_common_list(self, kwargs: Dict, output: Set[str], expectation: ContextManager) -> None:
        """Tests :meth:`DirCmp.common_list()` method.

        Args:
            kwargs: Named arguments to be passed to the method.
            output: Expected file paths returned by the method.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.ExitStack` if no exception is expected.

        """
        with expectation:
            assert set(self.dir_cmp.common_list(**kwargs)) == output

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    @pytest.mark.parametrize(
        "kwargs, output, expectation",
        [
            ({}, {'3/a.txt'}, does_not_raise()),
            ({'patterns': 'a*'}, {'3/a.txt'}, does_not_raise()),
            ({'patterns': ['b*', 'c*']}, set(), does_not_raise()),
            ({'paths': '3'}, None, raises(ValueError)),
            ({'paths': ['1', '2']}, set(), does_not_raise()),
            ({'patterns': 'a*', 'paths': ['1', '2']}, set(), does_not_raise()),
        ],
    )
    def test_ref_only_list(self, kwargs: Dict, output: Set[str], expectation: ContextManager) -> None:
        """Tests :meth:`DirCmp.ref_only_list()` method.

        Args:
            kwargs: Named arguments to be passed to the method.
            output: Expected file paths returned by the method.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.ExitStack` if no exception is expected.

        """
        with expectation:
            assert set(self.dir_cmp.ref_only_list(**kwargs)) == output

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    @pytest.mark.parametrize(
        "kwargs, output, expectation",
        [
            ({}, {'0/b.txt', '4/a.txt'}, does_not_raise()),
            ({'patterns': 'a*'}, {'4/a.txt'}, does_not_raise()),
            ({'patterns': ['b*', 'c*']}, {'0/b.txt'}, does_not_raise()),
            ({'paths': '3'}, None, raises(ValueError)),
            ({'paths': ['1', '2']}, set(), does_not_raise()),
            ({'patterns': 'a*', 'paths': ['1', '2']}, set(), does_not_raise()),
        ],
    )
    def test_target_only_list(self, kwargs: Dict, output: Set[str], expectation: ContextManager) -> None:
        """Tests :meth:`DirCmp.target_only_list()` method.

        Args:
            kwargs: Named arguments to be passed to the method.
            output: Expected file paths returned by the method.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.ExitStack` if no exception is expected.

        """
        with expectation:
            assert set(self.dir_cmp.target_only_list(**kwargs)) == output


@pytest.mark.parametrize("dir_cmp", [{'ref': 'citest/reference', 'target': 'citest/target'}], indirect=True)
class TestFileCmp(BaseTestFilesys):
    """Tests :mod:`filecmp` module."""

    @pytest.mark.parametrize(
        "filepath, output",
        [
            (Path('0', 'a.txt'), True),
            (Path('1', 'b.txt'), False),
            (Path('1', 'c.txt'), False),
            (Path('2', 'a.nw'), True),
            (Path('2', 'b.nwk'), False),
        ],
    )
    def test_file_cmp(self, filepath: StrPath, output: bool) -> None:
        """Tests :meth:`filecmp.file_cmp()` method.

        Args:
            filepath: Relative file path to compare between reference and target directory trees.
            output: Expected returned boolean value.

        """
        assert file_cmp(self.dir_cmp.ref_path / filepath, self.dir_cmp.target_path / filepath) == output, \
            f"Files should be {'equivalent' if output else 'different'}"
