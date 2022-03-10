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
"""Unit testing of `maf_to_fasta.py` script.

Typical usage example::

    $ pytest test_maf_to_fasta.py

"""

from contextlib import nullcontext as does_not_raise
import filecmp
from pathlib import Path
import re
from typing import ContextManager, Iterable, List, Optional, Pattern

import pytest
from pytest import raises

from ensembl.compara.filesys import PathLike
from ensembl.compara.hal import maf_to_fasta


class TestMafToFasta:
    """Tests script ``maf_to_fasta.py``"""

    ref_file_dir = None  # type: Path

    @pytest.fixture(scope='class', autouse=True)
    def setup(self) -> None:
        """Loads necessary fixtures and values as class attributes."""
        type(self).ref_file_dir = pytest.files_dir / 'hal_alignment'

    @pytest.mark.parametrize(
        "genome_names, exp_output, expectation",
        [
            (['genomeA.1', 'genomeB.1'], re.compile('^(?P<genome>genomeA\\.1|genomeB\\.1)[.](?P<seqid>.+)$'),
                does_not_raise()),
            (iter(['genomeA.1', 'genomeB.1']), None, raises(ValueError)),
            (['genomeA', 'genomeA.1'], None, raises(ValueError)),
            ([], None, raises(ValueError))
        ]
    )
    def test_compile_maf_src_regex(self, genome_names: Iterable[str], exp_output: Pattern[str],
                                   expectation: ContextManager) -> None:
        """Tests :func:`maf_to_fasta.compile_maf_src_regex()` function.

        Args:
            genome_names: The genome names expected to be in the input MAF file.
            exp_output: Expected return value of the function.
            expectation: Context manager for the expected exception. The test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

        """
        with expectation:
            # pylint: disable-next=no-member
            obs_output = maf_to_fasta.compile_maf_src_regex(genome_names)
            assert obs_output == exp_output

    @pytest.mark.parametrize(
        "maf_file, output_dir, genomes_file, out_file_rel_paths, expectation",
        [
            ('gabs.maf', 'gabs', 'gab_genomes.txt', ['0.fa', '0.json', '1.fa', '1.json'], does_not_raise()),
            ('gabs.maf', 'gabs', 'wrong_genomes.txt', [], raises(ValueError)),
            ('gabs.maf', 'gabs', None, [], raises(ValueError))
        ]
    )
    def test_convert_maf_to_fasta(self, maf_file: PathLike, output_dir: PathLike,
                                  genomes_file: Optional[PathLike], out_file_rel_paths: List[str],
                                  expectation: ContextManager, tmp_dir: Path) -> None:
        """Tests :func:`maf_to_fasta.convert_maf_to_fasta()` function.

        Args:
            maf_file: Input MAF file with alignment blocks. The src fields of
                this MAF file should be of the form '<genome>.<seqid>'.
            output_dir: Output directory under which FASTA and JSON files will be created.
            genomes_file: File listing the genomes in the input MAF file, one per line.
            out_file_rel_paths: Relative paths of the output FASTA and JSON files.
            expectation: Context manager for the expected exception. The test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.
            tmp_dir: Unit test temp directory (fixture).

        """
        maf_file_path = self.ref_file_dir / maf_file
        out_dir_path = tmp_dir / output_dir
        if genomes_file is not None:
            genomes_file = self.ref_file_dir / genomes_file

        with expectation:
            maf_to_fasta.convert_maf_to_fasta(maf_file_path, out_dir_path, genomes_file=genomes_file)

        ref_dir_path = self.ref_file_dir / output_dir
        for out_file_rel_path in out_file_rel_paths:
            out_file_path = out_dir_path / out_file_rel_path
            ref_file_path = ref_dir_path / out_file_rel_path
            assert filecmp.cmp(out_file_path, ref_file_path)

    @pytest.mark.parametrize(
        "non_negative_integer, exp_output, expectation",
        [
            (0, Path('.'), does_not_raise()),
            (10, Path('0'), does_not_raise()),
            ('75', None, raises(TypeError)),
            (-1, None, raises(ValueError))
        ]
    )
    def test_map_uint_to_path(self, non_negative_integer: int, exp_output: Path,
                              expectation: ContextManager) -> None:
        """Tests :func:`maf_to_fasta.map_uint_to_path()` function.

        Args:
            non_negative_integer: A non-negative integer.
            exp_output: Expected return value of the function.
            expectation: Context manager for the expected exception. The test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

        """
        with expectation:
            # pylint: disable-next=no-member
            obs_output = maf_to_fasta.map_uint_to_path(non_negative_integer)
            assert obs_output == exp_output
