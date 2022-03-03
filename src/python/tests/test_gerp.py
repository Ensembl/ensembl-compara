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
"""Unit testing of `gerp.py` script.

Typical usage example::

    $ pytest test_gerp.py

"""
from contextlib import nullcontext as does_not_raise
from pathlib import Path
from typing import ContextManager

import pytest
from pytest import raises
from pytest_mock import MockerFixture

from ensembl.compara.utils import gerp


def mock_gerp_call(cmd, *args, **kwargs):
    """Mock of `gerpcol` and `gerpelem` calls to generate the expected output."""
    if cmd[0].endswith('gerpcol'):
        # Example on how to create an empty file
        Path(f"{cmd[4]}.rates").touch()
    elif cmd[0].endswith('gerpelem'):
        # Example on how to create a predefined content in the expected file
        with open(Path(f"{cmd[2]}.elems"), 'w') as elems_file:
            elems_file.write("1\t2\t0.5\t0.4\n")


class TestGerp:
    """Tests script gerp.py"""

    msa_file = None  # type: Path
    tree_file = None  # type: Path

    @pytest.fixture(scope='class', autouse=True)
    def setup(self, tmp_dir: Path) -> None:
        """Loads necessary fixtures and values as class attributes."""
        # pylint: disable-next=no-member
        type(self).msa_file = tmp_dir / 'msa.fasta'  # type: ignore[attr-defined]
        type(self).msa_file.touch()
        # pylint: disable-next=no-member
        type(self).tree_file = tmp_dir / 'tree.nw'  # type: ignore[attr-defined]
        type(self).tree_file.touch()

    @pytest.mark.parametrize(
        "depth_threshold,gerp_exe_dir,expectation",
        [
            (None, None, does_not_raise()),
            (0.1, None, does_not_raise()),
            (None, '/my/path', does_not_raise()),
        ]
    )
    def test_gerp(self, mocker: MockerFixture, depth_threshold: float, gerp_exe_dir: str,
                  expectation: ContextManager) -> None:
        """Tests :func:`gerp.main()` function.

        Args:
            mocker: Fixture to mock objects
            depth_threshold: Constrained elements' depth threshold for shallow columns, in
                substitutions per site
            gerp_exe_dir: Path where `gerpcol` and `gerpelem` binaries can be found
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

        """
        mocker.patch('subprocess.run', side_effect=mock_gerp_call)
        with expectation:
            gerp.main(self.msa_file, self.tree_file, depth_threshold, gerp_exe_dir)
            assert Path(f"{self.msa_file}.rates").exists()
            assert Path(f"{self.msa_file}.rates.elems").exists()
