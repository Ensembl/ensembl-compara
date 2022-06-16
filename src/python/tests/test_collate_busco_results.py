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
"""Testing of `collate_busco_results.py` script.

Typical usage example::

    $ pytest collate_busco_results.py

"""

import sys
import subprocess
from pathlib import Path

from pytest import raises

from ensembl.compara.filesys import file_cmp


class TestCollateBusco:
    """Tests for the `collate_busco_results.py` script.
    """

    def test_collate_output(self, tmp_dir: Path) -> None:
        """Tests the output of `collate_busco_results.py` script.

        Args:
            tmp_dir: Unit test temp directory (fixture).
        """
        input_file = str(Path(__file__).parents[0] /
                         'flatfiles' / 'SpeciesTreeFromBusco' / 'busco_collate_fofn.txt')
        input_genes = str(Path(__file__).parents[0] /
                          'flatfiles' / 'SpeciesTreeFromBusco' / 'busco_collate_genes.tsv')
        output_stats = str(tmp_dir / "stats.tsv")
        output_taxa = str(tmp_dir / "taxa.tsv")

        # Run the command

        cmd = [sys.executable, str(Path(__file__).parents[3] / 'pipelines' /
                                   'SpeciesTreeFromBusco' / 'scripts' / 'collate_busco_results.py'),
               '-i', input_file, '-m', '0.6',
               '-o', str(tmp_dir), '-l', input_genes, '-s', output_stats, '-t', output_taxa]
        location = str(Path(__file__).parents[0])
        subprocess.check_call(cmd, cwd=location)

        # Compare with expected output:
        expected_stats = str(Path(__file__).parents[0] / "flatfiles" / "SpeciesTreeFromBusco"
                             / "collate_output_stats.tsv")
        expected_taxa = str(Path(__file__).parents[0] / "flatfiles" / "SpeciesTreeFromBusco"
                            / "collate_output_taxa.tsv")
        expected_gene1 = str(Path(__file__).parents[0] / "flatfiles" / "SpeciesTreeFromBusco"
                             / "collate_gene_prot_gene1.fas")
        expected_gene2 = str(Path(__file__).parents[0] / "flatfiles" / "SpeciesTreeFromBusco"
                             / "collate_gene_prot_gene2.fas")
        expected_gene3 = str(Path(__file__).parents[0] / "flatfiles" / "SpeciesTreeFromBusco"
                             / "collate_gene_prot_gene3.fas")
        expected_gene4 = str(Path(__file__).parents[0] / "flatfiles" / "SpeciesTreeFromBusco"
                             / "collate_gene_prot_gene4.fas")

        # Compare stats and taxa:
        assert file_cmp(output_stats, expected_stats)
        assert file_cmp(output_taxa, expected_taxa)

        # Compare per-gene output:
        assert file_cmp(str(tmp_dir / "gene_prot_gene1.fas"), expected_gene1)
        assert file_cmp(str(tmp_dir / "gene_prot_gene2.fas"), expected_gene2)
        assert file_cmp(str(tmp_dir / "gene_prot_gene3.fas"), expected_gene3)
        assert file_cmp(str(tmp_dir / "gene_prot_gene4.fas"), expected_gene4)

    def test_collate_for_empty_input(self, tmp_dir: Path) -> None:
        """Tests the `collate_busco_results.py` script when input is empty.

        Args:
            tmp_dir: Unit test temp directory (fixture).
        """
        input_file = str(Path(__file__).parents[0] /
                         'flatfiles' / 'SpeciesTreeFromBusco' / 'empty_file.txt')
        input_genes = str(Path(__file__).parents[0] /
                          'flatfiles' / 'SpeciesTreeFromBusco' / 'busco_collate_genes.tsv')
        output_stats = str(tmp_dir / "stats.tsv")
        output_taxa = str(tmp_dir / "taxa.tsv")

        # Run the command
        cmd = [sys.executable, str(Path(__file__).parents[3] / 'pipelines' /
                                   'SpeciesTreeFromBusco' / 'scripts' / 'collate_busco_results.py'),
               '-i', input_file, '-m', '0.5',
               '-o', str(tmp_dir), '-l', input_genes, '-s', output_stats, '-t', output_taxa]

        with raises(subprocess.CalledProcessError):
            subprocess.check_call(cmd)
