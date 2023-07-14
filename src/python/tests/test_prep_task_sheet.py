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
"""Unit testing of HalCacheChain pipeline script ``prep_task_sheet.py``."""

import filecmp
from pathlib import Path

import pytest
from pytest_console_scripts import ScriptRunner


class TestPrepTaskSheet:
    """Tests ``prep_task_sheet.py`` script."""

    ref_file_dir = None  # type: Path

    @pytest.fixture(scope="class", autouse=True)
    def setup(self) -> None:
        """Loads necessary fixtures and values as class attributes."""
        # pylint: disable-next=no-member
        type(self).ref_file_dir = pytest.files_dir / "hal_alignment"  # type: ignore
        type(self).script_path = Path(__file__).parents[3] / "pipelines" / "HalCacheChain" / "scripts" / "prep_task_sheet.py"

    @pytest.mark.parametrize(
        "in_file_name, out_file_name",
        [
            ("genomes.tsv", "prepped_genomes.tsv"),
            ("regions.tsv", "prepped_regions.tsv"),
            ("locations.tsv", "prepped_locations.tsv"),
        ],
    )
    def test_prep_task_sheet(
        self,
        in_file_name: str,
        out_file_name: str,
        script_runner: ScriptRunner,
        tmp_dir: Path,
    ) -> None:
        """Tests ``prep_task_sheet.py`` script."""

        in_file_path = self.ref_file_dir / "task_sheets" / in_file_name
        chrom_sizes_dir = self.ref_file_dir / "aln_cache" / "genome" / "chrom_sizes"
        out_file_path = tmp_dir / out_file_name

        cmd_args = [
            self.script_path,
            in_file_path,
            chrom_sizes_dir,
            out_file_path,
        ]

        script_runner.run(cmd_args, check=True)  # type: ignore

        ref_file_path = self.ref_file_dir / "task_sheets" / out_file_name
        assert filecmp.cmp(out_file_path, ref_file_path)
