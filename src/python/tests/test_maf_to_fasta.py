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
from importlib.abc import Loader
from importlib.machinery import ModuleSpec
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import re
import sys
from types import ModuleType
from typing import ContextManager, Iterable, List, Optional, Pattern

import pytest
from pytest import raises

from ensembl.compara.filesys.dircmp import PathLike


def import_module_from_file(module_file: PathLike) -> ModuleType:
    """Import module from file path.

    The name of the imported module is the basename of the specified module
    file without its extension.

    In addition to being returned by this function, the imported module is
    loaded into the sys.modules dictionary, allowing for commands such as
    :code:`from <module> import <class>`.

    Args:
        module_file: File path of module to import.

    Returns:
        The imported module.

    """
    if not isinstance(module_file, Path):
        module_file = Path(module_file)
    module_name = module_file.stem

    module_spec = spec_from_file_location(module_name, module_file)

    if not isinstance(module_spec, ModuleSpec):
        raise ImportError(f"ModuleSpec not created for module file '{module_file}'")
    if not isinstance(module_spec.loader, Loader):
        raise ImportError(f"no loader found for module file '{module_file}'")

    module = module_from_spec(module_spec)
    sys.modules[module_name] = module
    module_spec.loader.exec_module(module)

    return module


script_path = Path(__file__).parents[3] / 'scripts' / 'hal_alignment' / 'maf_to_fasta.py'
import_module_from_file(script_path)


# pylint: disable=import-error,wrong-import-order,wrong-import-position

import maf_to_fasta  # type: ignore

# pylint: enable=import-error,wrong-import-order,wrong-import-position


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
    def test_main(self, maf_file: PathLike, output_dir: PathLike, genomes_file: Optional[PathLike],
                  out_file_rel_paths: List[str], expectation: ContextManager, tmp_dir: Path) -> None:
        """Tests :func:`maf_to_fasta.main()` function.

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
        with expectation:
            maf_file_path = self.ref_file_dir / maf_file
            out_dir_path = tmp_dir / output_dir
            if genomes_file is not None:
                genomes_file = self.ref_file_dir / genomes_file

            # pylint: disable-next=no-member
            maf_to_fasta.main(maf_file_path, out_dir_path, genomes_file=genomes_file)

            for out_file_rel_path in out_file_rel_paths:
                obs_file_path = out_dir_path / out_file_rel_path
                ref_file_path = self.ref_file_dir / output_dir / out_file_rel_path
                assert filecmp.cmp(obs_file_path, ref_file_path)

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
