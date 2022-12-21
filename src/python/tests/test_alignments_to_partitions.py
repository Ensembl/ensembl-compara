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
"""Testing of `alignments_to_partitions.py` script.

Typical usage example::

    $ pytest alignments_to_partitions.py

"""

import sys
import subprocess
from pathlib import Path

from pytest import raises

from ensembl.compara.filesys import file_cmp


class TestAlignmentsToParitions:
    """Tests for the `alignments_to_partitions.py` script.
    """

    def test_merge_output(self, tmp_dir: Path) -> None:
        """Tests the output of `alignments_to_partitions.py` script.

        Args:
            tmp_dir: Unit test temp directory (fixture).
        """
        input_file = str(Path(__file__).parents[2] /
                         'test_data' / 'flatfiles' / 'SpeciesTreeFromBusco' / 'busco_merge_input_fofn.txt')
        input_taxa = str(Path(__file__).parents[2] /
                         'test_data' / 'flatfiles' / 'SpeciesTreeFromBusco' / 'collate_output_taxa.tsv')
        output_fasta = str(tmp_dir / "merged_fasta.tsv")
        output_parts = str(tmp_dir / "paritions.tsv")

        # Run the command
        cmd = [sys.executable, str(Path(__file__).parents[3] / 'pipelines' /
                                   'SpeciesTreeFromBusco' / 'scripts' /
                                   'alignments_to_partitions.py'),
               '-i', input_file,
               '-o', output_fasta, '-p', output_parts, '-t', input_taxa]
        location = str(Path(__file__).parents[0])
        subprocess.check_call(cmd, cwd=location)

        # Compare with expected output:
        expected_fasta = str(Path(__file__).parents[2] / 'test_data' / "flatfiles" / "SpeciesTreeFromBusco"
                             / "busco_merged.fas")

        assert file_cmp(output_fasta, expected_fasta)

    def test_merge_for_empty_input(self, tmp_dir: Path) -> None:
        """Tests the `alignments_to_partitions.py` script when input is empty.

        Args:
            tmp_dir: Unit test temp directory (fixture).
        """
        input_file = str(Path(__file__).parents[2] /
                         'test_data' / 'flatfiles' / 'SpeciesTreeFromBusco' / 'empty_file.txt')
        input_taxa = str(Path(__file__).parents[2] /
                         'test_data' / 'flatfiles' / 'SpeciesTreeFromBusco' / 'collate_output_taxa.tsv')
        output_fasta = str(tmp_dir / "merged_fasta.tsv")
        output_parts = str(tmp_dir / "paritions.tsv")

        # Run the command
        cmd = [sys.executable, str(Path(__file__).parents[3] / 'pipelines' /
                                   'SpeciesTreeFromBusco' / 'scripts' /
                                   'alignments_to_partitions.py'),
               '-i', input_file,
               '-o', output_fasta, '-p', output_parts, '-t', input_taxa]
        location = str(Path(__file__).parents[0])

        with raises(subprocess.CalledProcessError):
            subprocess.check_call(cmd, cwd=location)
