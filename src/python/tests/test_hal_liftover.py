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
"""Unit testing of :mod:`cmd.hal_liftover` module."""

import filecmp
from pathlib import Path

import pytest
from pytest_console_scripts import ScriptRunner
from pytest_mock import MockerFixture

from ensembl.compara.utils.tools import import_module_from_file


helpers_module_path = Path(__file__).parents[0] / "helpers.py"
helpers = import_module_from_file(helpers_module_path)

# pylint: disable=import-error,wrong-import-order,wrong-import-position

from helpers import mock_two_bit_to_fa

# pylint: enable=import-error,wrong-import-order,wrong-import-position


class TestHalLiftover:
    """Tests ``hal-liftover`` console script."""

    ref_file_dir = None  # type: Path

    @pytest.fixture(scope="class", autouse=True)
    def setup(self) -> None:
        """Loads necessary fixtures and values as class attributes."""
        # pylint: disable-next=no-member
        type(self).ref_file_dir = pytest.files_dir / "hal_alignment"  # type: ignore

    @pytest.mark.parametrize(
        "hal_file, src_genome, dest_genome, output_file, src_region, hal_cache, output_format",
        [
            ("aln.hal", "genomeA", "genomeB", "genomeA_to_genomeB.json", "chr1:16-18:1", "aln_cache", "JSON"),
            ("aln.hal", "genomeA", "genomeB", "genomeA_to_genomeB.tsv", "chr1:16-18:1", "aln_cache", "TSV"),
        ],
    )
    @pytest.mark.script_launch_mode("inprocess")
    def test_hal_liftover(
        self,
        hal_file: str,
        src_genome: str,
        dest_genome: str,
        output_file: str,
        src_region: str,
        hal_cache: str,
        output_format: str,
        script_runner: ScriptRunner,
        mocker: MockerFixture,
        tmp_path: Path,
    ) -> None:
        """Tests ``hal-liftover`` console script."""
        mocker.patch("subprocess.run", side_effect=mock_two_bit_to_fa)

        hal_file_path = self.ref_file_dir / hal_file
        hal_cache_path = self.ref_file_dir / hal_cache
        out_file_path = tmp_path / output_file

        cmd_args = [
            "hal-liftover",
            hal_file_path,
            src_genome,
            dest_genome,
            out_file_path,
            "--src-region",
            src_region,
            "--hal-cache",
            hal_cache_path,
            "--output-format",
            output_format,
        ]

        script_runner.run(cmd_args, check=True)  # type: ignore

        ref_file_path = self.ref_file_dir / output_file
        assert filecmp.cmp(out_file_path, ref_file_path)
