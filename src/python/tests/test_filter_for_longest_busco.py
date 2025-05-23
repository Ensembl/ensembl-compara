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
"""Testing of `filter_for_longest_busco.py` script.

Typical usage example::

    $ pytest filter_for_longest_busco.py

"""

import sys
import subprocess

from pathlib import Path
from pytest import raises

from ensembl.compara.filesys import file_cmp


class TestFilterForLongestBusco:
    """Tests for the `filter_for_longest_busco.py` script.
    """

    def test_filter_for_longest_output(self, tmp_path: Path) -> None:
        """Tests the output of `filter_for_longest_busco.py` script.

        Args:
            tmp_path: Unit test temp directory (fixture).
        """
        input_file = str(Path(__file__).parents[2] /
                         'test_data' / 'flatfiles' / 'SpeciesTreeFromBusco' / 'busco_filter_test.fas')
        output_file = str(tmp_path / "longest_busco.fas")
        output_genes = str(tmp_path / "busco_genes.tsv")

        # Run the command
        cmd = [sys.executable, str(Path(__file__).parents[3] / 'pipelines' /
                                   'SpeciesTreeFromBusco' / 'scripts' / 'filter_for_longest_busco.py'),
               '-i', input_file,
               '-o', output_file, '-l', output_genes]
        subprocess.check_call(cmd)

        # Compare with expected output:
        expected_genes = str(Path(__file__).parents[2] / 'test_data' / 'flatfiles' /
                             'SpeciesTreeFromBusco' / 'busco_filter_test_genes.tsv')
        expected_output = str(Path(__file__).parents[2] / 'test_data' / "flatfiles" /
                              "SpeciesTreeFromBusco" / "busco_filter_test_output.fas")

        assert file_cmp(tmp_path / "longest_busco.fas", expected_output)  # type: ignore
        assert file_cmp(tmp_path / "busco_genes.tsv", expected_genes)  # type: ignore

    def test_filter_for_longest_missing_input(self) -> None:
        """Tests `filter_for_longest_busco.py` script when input file is missing.

        Args:
        """
        input_file = ""
        output_file = "dummy.fas"
        output_genes = "dummy.tsv"
        # Run the command
        cmd = [sys.executable, str(Path(__file__).parents[3] / 'pipelines' /
                                   'SpeciesTreeFromBusco' / 'scripts' / 'filter_for_longest_busco.py'),
               '-i', input_file,
               '-o', output_file, '-l', output_genes]
        with raises(subprocess.CalledProcessError):
            subprocess.check_call(cmd)

    def test_filter_for_longest_empty_input(self, tmp_path: Path) -> None:
        """Tests `filter_for_longest_busco.py` script when input file is empty.

        Args:
            tmp_path: Unit test temp directory (fixture).
        """
        input_file = ""
        input_file = str(Path(__file__).parents[2] / 'test_data' /
                         'flatfiles' / 'SpeciesTreeFromBusco' / 'empty_file.txt')
        output_file = str(tmp_path / "dummy.fas")
        output_genes = str(tmp_path / "dummy.tsv")
        # Run the command
        cmd = [sys.executable, str(Path(__file__).parents[3] / 'pipelines' /
                                   'SpeciesTreeFromBusco' / 'scripts' / 'filter_for_longest_busco.py'),
               '-i', input_file,
               '-o', output_file, '-l', output_genes]
        with raises(subprocess.CalledProcessError):
            subprocess.check_call(cmd)
