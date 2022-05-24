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
"""Testing of `` script.

Typical usage example::

    $ pytest

"""

from pathlib import Path
import pytest
import subprocess
import os
import sys

from ensembl.compara.filesys import file_cmp
from ensembl.plugins.pytest_unittest import tmp_dir


class TestFilterForLongestBusco:
    """Tests for the `filter_for_longest_busco.py` script.
    """

    def test_filter_for_longest(self, tmp_dir: Path) -> None:
        """Tests the output of `filter_for_longest_busco.py` script.

        Args:
            tmp_dir: Unit test temp directory (fixture).
        """
        # Run the command
        cmd = [sys.executable, str(Path(__file__).parents[3] / 'pipelines' / 'SpeciesTreeFromBusco' / 'scripts' / 'filter_for_longest_busco.py'),
               '-i', str(Path(__file__).parents[3] / 'src' / 'python' / 'tests' / 'flatfiles' / 'busco_filter_test.fas'), '-o', str(tmp_dir / "longest_busco.fas"),
               '-l', str(tmp_dir / "busco_genes.tsv")]
        subprocess.check_call(cmd)

        # Compare with expected output:
        expected_genes = str(Path(__file__).parents[0] / "flatfiles/busco_filter_test_genes.tsv")
        expected_output = str(Path(__file__).parents[0] / "flatfiles/busco_filter_test_output.fas")

        assert file_cmp(tmp_dir / "longest_busco.fas", expected_output)  # type: ignore
        assert file_cmp(tmp_dir / "busco_genes.tsv", expected_genes)  # type: ignore
