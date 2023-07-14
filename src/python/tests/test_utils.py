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
"""Unit testing of :mod:`utils` module.

The unit testing is divided into one test class per submodule/class found in this module, and one test method
per public function/class method.

Typical usage example::

    $ pytest test_utils.py

"""

from contextlib import nullcontext as does_not_raise
import filecmp
from pathlib import Path
import subprocess
from typing import Any, ContextManager, Dict, Iterable, List, Mapping, Tuple

import pytest
from pytest import raises
from pytest_mock import MockerFixture

from ensembl.compara.utils import to_list

from ensembl.compara.utils.hal import (
    extract_region_sequences_from_2bit,
    extract_regions_from_bed,
    make_src_region_file,
    SimpleRegion,
)
from ensembl.compara.utils.tools import import_module_from_file
from ensembl.compara.utils.ucsc import load_chrom_sizes_file


helpers_module_path = Path(__file__).parents[0] / "helpers.py"
helpers = import_module_from_file(helpers_module_path)

# pylint: disable=import-error,wrong-import-order,wrong-import-position

from helpers import mock_two_bit_to_fa

# pylint: enable=import-error,wrong-import-order,wrong-import-position


class TestTools:
    """Tests :mod:`tools` submodule."""

    @pytest.mark.parametrize(
        "arg, output", [(None, []), ("", []), (0, []), ("a", ["a"]), (["a", "b"], ["a", "b"])],
    )
    def test_file_cmp(self, arg: Any, output: List[Any]) -> None:
        """Tests :meth:`tools.to_list()` method.

        Args:
            arg: Element to be converted to a list.
            output: Expected returned list.

        """
        assert to_list(arg) == output, "List returned differs from the one expected"


class TestUcscUtils:
    """Tests :mod:`ucsc` utils submodule."""

    ref_file_dir = None  # type: Path

    @pytest.fixture(scope="class", autouse=True)
    def setup(self) -> None:
        """Loads necessary fixtures and values as class attributes."""
        # pylint: disable-next=no-member
        type(self).ref_file_dir = pytest.files_dir / "hal_alignment"  # type: ignore

    @pytest.mark.parametrize(
        "chrom_sizes_file_name, exp_output, expectation",
        [
            ("genomeA.chrom.sizes", {"chr1": 33}, does_not_raise()),
            ("too_few_cols.chrom.sizes", None, raises(ValueError)),
            ("too_many_cols.chrom.sizes", None, raises(ValueError)),
        ],
    )
    def test_load_chrom_sizes_file(
        self, chrom_sizes_file_name: str, exp_output: Dict[str, int], expectation: ContextManager
    ) -> None:
        """Tests :func:`utils.ucsc.load_chrom_sizes_file()` function."""
        with expectation:
            chrom_sizes_dir_path = self.ref_file_dir / "aln_cache" / "genome" / "chrom_sizes"
            chrom_sizes_file_path = chrom_sizes_dir_path / chrom_sizes_file_name
            obs_output = load_chrom_sizes_file(chrom_sizes_file_path)
            assert obs_output == exp_output


class TestHalUtils:
    """Tests :mod:`ucsc` utils submodule."""

    ref_file_dir = None  # type: Path

    @pytest.fixture(scope="class", autouse=True)
    def setup(self) -> None:
        """Loads necessary fixtures and values as class attributes."""
        # pylint: disable-next=no-member
        type(self).ref_file_dir = pytest.files_dir / "hal_alignment"  # type: ignore

    @pytest.mark.parametrize(
        "regions, two_bit_file_name, exp_output, expectation",
        [
            ([SimpleRegion("chr1", 15, 18, "+")], "genomeA.2bit", ["TAA"], does_not_raise()),
            (
                [SimpleRegion("chr1", 31, 34, "+")],
                "genomeA.2bit",
                None,
                raises(subprocess.CalledProcessError),
            ),
        ],
    )
    def test_extract_region_sequences_from_2bit(
        self,
        regions: Iterable[SimpleRegion],
        two_bit_file_name: str,
        exp_output: List[str],
        expectation: ContextManager,
        mocker: MockerFixture,
    ) -> None:
        """Tests :func:`utils.hal.extract_region_sequences_from_2bit()` function."""
        mocker.patch("subprocess.run", side_effect=mock_two_bit_to_fa)
        with expectation:
            two_bit_dir_path = self.ref_file_dir / "aln_cache" / "genome" / "2bit"
            two_bit_file_path = two_bit_dir_path / two_bit_file_name
            obs_output = extract_region_sequences_from_2bit(regions, two_bit_file_path)
            assert obs_output == exp_output

    @pytest.mark.parametrize(
        "bed_file_name, exp_output",
        [
            ("a2b.one2one.plus.flank0.src.bed", [SimpleRegion("chr1", 15, 18, "+")]),
            ("a2b.one2one.plus.flank1.src.bed", [SimpleRegion("chr1", 14, 19, "+")]),
            ("a2b.chr_start.flank1.src.bed", [SimpleRegion("chr1", 0, 3, "+")]),
            ("a2b.chr_end.flank1.src.bed", [SimpleRegion("chr1", 30, 33, "+")]),
        ],
    )
    def test_extract_regions_from_bed(self, bed_file_name: str, exp_output: List[str]) -> None:
        """Tests :func:`utils.hal.extract_regions_from_bed()` function."""
        bed_file_path = self.ref_file_dir / bed_file_name
        obs_output = extract_regions_from_bed(bed_file_path)
        assert obs_output == exp_output

    @pytest.mark.parametrize(
        "region_tuple, genome, chrom_sizes, bed_file_name, flank_length, expectation",
        [
            (
                ("chr1", 16, 18, 1),
                "genomeA",
                {"chr1": 33},
                "a2b.one2one.plus.flank0.src.bed",
                0,
                does_not_raise(),
            ),
            (
                ("chr1", 16, 18, 1),
                "genomeA",
                {"chr1": 33},
                "a2b.one2one.plus.flank1.src.bed",
                1,
                does_not_raise(),
            ),
            (
                ("chr1", 1, 2, 1),
                "genomeA",
                {"chr1": 33},
                "a2b.chr_start.flank1.src.bed",
                1,
                does_not_raise(),
            ),
            (
                ("chr1", 32, 33, 1),
                "genomeA",
                {"chr1": 33},
                "a2b.chr_end.flank1.src.bed",
                1,
                does_not_raise(),
            ),
            (
                ("chr1", 16, 18, 1),
                "genomeA",
                {"chr1": 33},
                "a2b.negative_flank.src.bed",
                -1,
                raises(ValueError, match=r"'flank_length' must be greater than or equal to 0: -1"),
            ),
            (
                ("chrN", 1, 3, 1),
                "genomeA",
                {"chr1": 33},
                "a2b.unknown_chr.src.bed",
                0,
                raises(ValueError, match=r"chromosome ID 'chrN' not found in genome 'genomeA'"),
            ),
            (
                ("chr1", 32, 34, 1),
                "genomeA",
                {"chr1": 33},
                "a2b.chr_end.oor.src.bed",
                0,
                raises(
                    ValueError,
                    match=r"region end \(34\) must not be greater than the"
                    r" corresponding chromosome length \(chr1: 33\)",
                ),
            ),
        ],
    )
    def test_make_src_region_file(
        self,
        region_tuple: Tuple[str, int, int, int],
        genome: str,
        chrom_sizes: Mapping[str, int],
        bed_file_name: str,
        flank_length: int,
        expectation: ContextManager,
        tmp_dir: Path,
    ) -> None:
        """Tests :func:`utils.hal.make_src_region_file()` function."""
        with expectation:
            out_file_path = tmp_dir / bed_file_name
            make_src_region_file(*region_tuple, genome, chrom_sizes, out_file_path, flank_length)
            ref_file_path = self.ref_file_dir / bed_file_name
            assert filecmp.cmp(out_file_path, ref_file_path)
