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
"""Unit testing of `hal_gene_liftover.py` script.

The unit testing is divided into one test class for all top-level functions, and one test class per
class found in this script; and within each test class, one test method per public function/method.

Typical usage example::

    $ pytest test_hal_gene_liftover.py

"""
import filecmp
from importlib.abc import Loader
from importlib.machinery import ModuleSpec
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import sys
from types import ModuleType
from typing import ContextManager, Iterable, Mapping, Union

import pytest
from pytest import raises

from contextlib import nullcontext as does_not_raise


def import_module_from_file(module_file: Union[Path, str]) -> ModuleType:
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


script_path = Path(__file__).parents[3] / 'scripts' / 'hal_alignment' / 'hal_gene_liftover.py'
import_module_from_file(script_path)

# pylint: disable=import-error,wrong-import-position

import hal_gene_liftover  # type: ignore
from hal_gene_liftover import SimpleRegion

# pylint: enable=import-error,wrong-import-position


class TestHalGeneLiftover:
    """Tests script hal_gene_liftover.py"""

    ref_file_dir = None  # type: Path

    @pytest.fixture(scope='class', autouse=True)
    def setup(self) -> None:
        """Loads necessary fixtures and values as class attributes."""
        type(self).ref_file_dir = pytest.files_dir / 'hal_alignment'

@pytest.mark.parametrize(
    "region, exp_output, expectation",
    [
        ('chr1:16-18:1', SimpleRegion('chr1', 15, 18, '+'), does_not_raise()),
        ('chrX:23-25:-1', SimpleRegion('chrX', 22, 25, '-'), does_not_raise()),
        ('chr1:0-2:1', None, raises(ValueError,
         match=r"region start must be greater than or equal to 1: 0")),
        ('chr1:2-1:1', None, raises(ValueError,
         match=r"region 'chr1:2-1:1' has inverted/empty interval")),
        ('chr1:1-1:+', None, raises(ValueError,
         match=r"region 'chr1:1-1:\+' has invalid strand: '\+'")),
        ('dummy', None, raises(ValueError, match=r"region 'dummy' could not be parsed"))
    ]
)
def test_parse_region(self, region: str, exp_output: SimpleRegion,
                      expectation: ContextManager) -> None:
    """Tests :func:`hal_gene_liftover.parse_region()` function.

    Args:
        region: Region string.
        exp_output: Expected return value of the function.
        expectation: Context manager for the expected exception, i.e. the test will only pass if that
            exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

    """
    with expectation:
        obs_output = hal_gene_liftover.parse_region(region)
        assert obs_output == exp_output

@pytest.mark.parametrize(
    "regions, chrom_sizes, bed_file, flank_length, expectation",
    [
        ([SimpleRegion('chr1', 15, 18, '+')], {'chr1': 33}, 'a2b.one2one.plus.flank0.src.bed', 0,
         does_not_raise()),
        ([SimpleRegion('chr1', 15, 18, '+')], {'chr1': 33}, 'a2b.one2one.plus.flank1.src.bed', 1,
         does_not_raise()),
        ([SimpleRegion('chr1', 0, 2, '+')], {'chr1': 33}, 'a2b.chrom_start.flank1.src.bed', 1,
         does_not_raise()),
        ([SimpleRegion('chr1', 31, 33, '+')], {'chr1': 33}, 'a2b.chrom_end.flank1.src.bed', 1,
         does_not_raise()),
        ([SimpleRegion('chr1', 15, 18, '+')], {'chr1': 33}, 'a2b.negative_flank.src.bed', -1,
         raises(ValueError, match=r"'flank_length' must be greater than or equal to 0: -1")),
        ([SimpleRegion('chrN', 0, 3, '+')], {'chr1': 33}, 'a2b.unknown_chrom.src.bed', 0,
         raises(ValueError, match=r"chromosome ID not found in input file: 'chrN'")),
        ([SimpleRegion('chr1', 31, 34, '+')], {'chr1': 33}, 'a2b.chrom_end.oor.src.bed', 0,
         raises(ValueError,
         match=r"region end \(34\) must not be greater than chromosome length \(33\)"))
    ]
)
def test_make_src_region_file(self, regions: Iterable[SimpleRegion],
                              chrom_sizes: Mapping[str, int], bed_file: str, flank_length: int,
                              expectation: ContextManager, tmp_dir: Path) -> None:
    """Tests :func:`hal_gene_liftover.make_src_region_file()` function.

    Args:
        regions: Regions to write to output file.
        chrom_sizes: Dictionary mapping chromosome names to their lengths.
        bed_file: Path of BED file to output.
        flank_length: Length of upstream/downstream flanking regions to request.
        expectation: Context manager for the expected exception, i.e. the test will only pass if that
            exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.
        tmp_dir: Unit test temp directory (fixture).

    """
    with expectation:
        out_file_path = tmp_dir / bed_file
        hal_gene_liftover.make_src_region_file(regions, chrom_sizes, out_file_path,
                                               flank_length)
        ref_file_path = self.ref_file_dir / bed_file
        assert filecmp.cmp(out_file_path, ref_file_path)
