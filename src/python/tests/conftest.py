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
"""Local directory-specific hook implementations.

Since this file is located at the root of all ensembl-compara tests, every test in every subfolder will have
access to the plugins, hooks and fixtures defined here.

"""
# Disable all the redefined-outer-name violations due to how pytest fixtures work
# pylint: disable=redefined-outer-name

import os
from pathlib import Path
import shutil
import time

import pytest
from _pytest.fixtures import FixtureRequest

from ensembl.compara.filesys import DirCmp, PathLike


pytest_plugins = ("ensembl.plugins.pytest_unittest",)


def pytest_configure() -> None:
    """Adds global variables and configuration attributes required by Compara's unit tests.

    `Pytest initialisation hook
    <https://docs.pytest.org/en/latest/reference.html#_pytest.hookspec.pytest_configure>`_.

    """
    pytest.dbs_dir = Path(__file__).parent / 'databases'  # type: ignore[attr-defined]
    pytest.files_dir = Path(__file__).parent / 'flatfiles'  # type: ignore[attr-defined]


@pytest.fixture(scope='session')
def dir_cmp(request: FixtureRequest, tmp_dir: PathLike) -> DirCmp:
    """Returns a directory tree comparison (:class:`DirCmp`) object.

    Requires a dictionary with the following keys:

        ref (:obj:`PathLike`): Reference root directory path.
        target (:obj:`PathLike`): Target root directory path.

    passed via `request.param`. In both cases, if a relative path is provided, the starting folder will be
    ``src/python/tests/flatfiles``. This fixture is intended to be used via indirect parametrization, for
    example::

        @pytest.mark.parametrize("dir_cmp", [{'ref': 'citest/reference', 'target': 'citest/target'}],
                                 indirect=True)
        def test_method(..., dir_cmp: DirCmp, ...):

    Args:
        request: Access to the requesting test context.
        tmp_dir: Temporary directory path.

    """
    # Get the source and temporary absolute paths for reference and target root directories
    ref = Path(request.param['ref'])  # type: ignore[attr-defined]
    ref_src = ref if ref.is_absolute() else pytest.files_dir / ref  # type: ignore[attr-defined,operator]
    ref_tmp = Path(tmp_dir) / str(ref).replace(os.path.sep, '_')
    target = Path(request.param['target'])  # type: ignore[attr-defined]
    target_src = target if target.is_absolute() else pytest.files_dir / target  # type: ignore[attr-defined]
    target_tmp = Path(tmp_dir) / str(target).replace(os.path.sep, '_')
    # Copy directory trees (if they have not been copied already) ignoring file metadata
    if not ref_tmp.exists():
        shutil.copytree(ref_src, ref_tmp, copy_function=shutil.copy)
    # Sleep one second in between to ensure the timestamp differs between reference and target files
    time.sleep(1)
    if not target_tmp.exists():
        shutil.copytree(target_src, target_tmp, copy_function=shutil.copy)
    return DirCmp(ref_tmp, target_tmp)
