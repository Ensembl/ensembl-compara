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
import filecmp
from pathlib import Path
from typing import Callable, ContextManager, Dict, Set

import pytest
from pytest import raises
from _pytest.fixtures import FixtureRequest

from ensembl.compara.filesys import DirCmp, file_cmp, PathLike


@pytest.fixture(scope='class')
def dir_cmp(request: FixtureRequest, dir_cmp_factory: Callable) -> None:
    """Assigns a :class:`DirCmp` object to a pytest class attribute.

    The object compares ``ensembl-compara/src/python/tests/flatfiles/citest`` reference and target directory
    trees.

    """
    request.cls.dir_cmp = dir_cmp_factory('citest')


@pytest.mark.usefixtures('dir_cmp')
class TestDirCmp:
    """Tests :class:`DirCmp` class."""

    dir_cmp = None  # type: DirCmp

    @pytest.mark.dependency()
    def test_init(self, tmp_dir: Path) -> None:
        """Tests that the object :class:`DirCmp` is initialised correctly."""
        assert tmp_dir / 'citest' / 'reference' == self.dir_cmp.ref_path, "Unexpected reference root path"
        assert tmp_dir / 'citest' / 'target' == self.dir_cmp.target_path, "Unexpected target root path"
        # Check the files at the root
        assert self.dir_cmp.common_files == set(), "Found unexpected files at the root of both trees"
        assert self.dir_cmp.ref_only == {'3/a.txt'}, "Expected '3/a.txt' at reference tree's root"
        assert self.dir_cmp.target_only == set(), "Found unexpected files at target tree's root"
        # Check each subdirectory
        expected = {
            1: {'common_files': {'b.txt', 'c.txt'}},
            2: {'common_files': {'a.nw', 'b.nwk'}},
        }
        for i in expected:
            key = Path(str(i))
            for attr in ['common_files', 'ref_only', 'target_only', 'subdirs']:
                if attr in expected[i]:
                    assert getattr(self.dir_cmp.subdirs[key], attr) == expected[i][attr], \
                        "Expected {} '{}' at '{}/'".format(attr, "', '".join(expected[i][attr]), i)
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
        ids=pytest.get_param_repr
    )
    def test_apply_test(self, kwargs: Dict, output: Set[str], expectation: ContextManager) -> None:
        """Tests DirCmp's :meth:`DirCmp.apply_test()` method.

        Args:
            kwargs: Named arguments to be passed to the method.
            output: Expected file paths returned by the method.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`contextlib.nullcontext` if no exception is expected.

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
        ids=pytest.get_param_repr
    )
    def test_common_list(self, kwargs: Dict, output: Set[str], expectation: ContextManager) -> None:
        """Tests DirCmp's :meth:`DirCmp.common_list()` method.

        Args:
            kwargs: Named arguments to be passed to the method.
            output: Expected file paths returned by the method.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`contextlib.nullcontext` if no exception is expected.

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
        ids=pytest.get_param_repr
    )
    def test_ref_only_list(self, kwargs: Dict, output: Set[str], expectation: ContextManager) -> None:
        """Tests DirCmp's :meth:`DirCmp.ref_only_list()` method.

        Args:
            kwargs: Named arguments to be passed to the method.
            output: Expected file paths returned by the method.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`contextlib.nullcontext` if no exception is expected.

        """
        with expectation:
            assert set(self.dir_cmp.ref_only_list(**kwargs)) == output

    @pytest.mark.dependency(depends=['test_init'], scope='class')
    @pytest.mark.parametrize(
        "kwargs, output, expectation",
        [
            ({}, {'0/b.txt'}, does_not_raise()),
            ({'patterns': 'a*'}, set(), does_not_raise()),
            ({'patterns': ['b*', 'c*']}, {'0/b.txt'}, does_not_raise()),
            ({'paths': '3'}, None, raises(ValueError)),
            ({'paths': ['1', '2']}, set(), does_not_raise()),
            ({'patterns': 'a*', 'paths': ['1', '2']}, set(), does_not_raise()),
        ],
        ids=pytest.get_param_repr
    )
    def test_target_only_list(self, kwargs: Dict, output: Set[str], expectation: ContextManager) -> None:
        """Tests DirCmp's :meth:`DirCmp.target_only_list()` method.

        Args:
            kwargs: Named arguments to be passed to the method.
            output: Expected file paths returned by the method.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`contextlib.nullcontext` if no exception is expected.

        """
        with expectation:
            assert set(self.dir_cmp.target_only_list(**kwargs)) == output


@pytest.mark.usefixtures('dir_cmp')
class TestFileCmp:
    """Tests :mod:`filecmp` module."""

    dir_cmp = None  # type: DirCmp

    @pytest.mark.parametrize(
        "filepath, output",
        [
            (Path('0', 'a.txt'), True),
            (Path('1', 'b.txt'), False),
            (Path('1', 'c.txt'), False),
            (Path('2', 'a.nw'), True),
            (Path('2', 'b.nwk'), False),
        ],
        ids=pytest.get_param_repr
    )
    def test_file_cmp(self, filepath: PathLike, output: bool) -> None:
        """Tests :meth:`filecmp.file_cmp()` method.

        Args:
            filepath: Relative file path to compare between reference and target directory trees.
            output: Expected returned boolean value.

        """
        assert file_cmp(self.dir_cmp.ref_path / filepath, self.dir_cmp.target_path / filepath) == output, \
            f"Files should be {'equivalent' if output else 'different'}"
