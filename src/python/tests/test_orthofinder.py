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
"""Unit testing of :mod:`orthtools` module.

The unit testing is divided into one test class per submodule/class found in this module, and one test method
per public function/class method.

Typical usage example::

    $ pytest test_orthofinder.py

"""

from contextlib import nullcontext as does_not_raise
import filecmp
from pathlib import Path
import subprocess
from typing import ContextManager

import pytest
from pytest import raises

from ensembl.compara.orthtools import prepare_input_orthofinder

@pytest.mark.parametrize(
    "source_dir, target_dir, expectation",
    [
        ("orthtools", "test1", does_not_raise()),
        ("orthtools", "test1", raises(FileExistsError)),
        ("orthology_tools", "test2", raises(subprocess.CalledProcessError))
    ]
)
def test_prepare_input_orthofinder(source_dir: str, target_dir: str, tmp_dir: Path,
                                   expectation: ContextManager) -> None:
    """Tests :func:`orthtools.prepare_input_orthofinder()` function.

    Args:
        source_dir: Path to the directory containing input fasta files.
        target_dir: Path to the directory where the input data will be copied for OrthoFinder to use.
        tmp_dir: Unit test temp directory (fixture).
        expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

    """
    from_dir = pytest.files_dir / source_dir
    to_dir = tmp_dir / target_dir
    with expectation:
        prepare_input_orthofinder(from_dir, to_dir)
        common = ["gallus_gallus_core_99_6.fasta", "homo_sapiens_core_99_38.fasta"]
        assert filecmp.cmpfiles(from_dir, to_dir, common, shallow=False) == (common, [], [])
