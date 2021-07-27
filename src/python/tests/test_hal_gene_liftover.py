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
from typing import ContextManager, Dict, Union

import pytest
from pytest import raises

if sys.version_info >= (3, 7):
    from contextlib import nullcontext as does_not_raise
else:
    from contextlib import ExitStack as does_not_raise


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
        type(self).ref_file_dir = (
                    pytest.files_dir / 'scripts' / 'hal_alignment' / 'hal_gene_liftover')

    @pytest.mark.parametrize(
        "kwargs, exp_output, expectation",
        [
            ({'region': 'chr1:16-18:1'}, SimpleRegion('chr1', 15, 18, '+'), does_not_raise()),
            ({'region': 'chr1:16-18:-1'}, SimpleRegion('chr1', 15, 18, '-'), does_not_raise()),
            ({'region': 'chr1:23-25:1'}, SimpleRegion('chr1', 22, 25, '+'), does_not_raise()),
            ({'region': 'chr1:23-25:-1'}, SimpleRegion('chr1', 22, 25, '-'), does_not_raise()),
            ({'region': 'chr1:7-8:1'}, SimpleRegion('chr1', 6, 8, '+'), does_not_raise()),
            ({'region': 'chr1:27-32:1'}, SimpleRegion('chr1', 26, 32, '+'), does_not_raise()),
            ({'region': 'chr1:1-2:1'}, SimpleRegion('chr1', 0, 2, '+'), does_not_raise()),
            ({'region': 'chr1:32-33:1'}, SimpleRegion('chr1', 31, 33, '+'), does_not_raise()),
            ({'region': 'chrN:1-3:1'}, SimpleRegion('chrN', 0, 3, '+'), does_not_raise()),
            ({'region': 'chr1:32-34:1'}, SimpleRegion('chr1', 31, 34, '+'), does_not_raise()),
            ({'region': 'chr1:0-2:1'}, None,
             raises(ValueError, match=r"region start must be greater than or equal to 1: 0")),
            ({'region': 'chr1:2-1:1'}, None,
             raises(ValueError, match=r"region 'chr1:2-1:1' has inverted/empty interval")),
            ({'region': 'chr1:1-1:+'}, None,
             raises(ValueError, match=r"region 'chr1:1-1:\+' has invalid strand: '\+'")),
            ({'region': 'chr1:1-1:-'}, None,
             raises(ValueError, match=r"region 'chr1:1-1:-' has invalid strand: '-'")),
            ({'region': 'dummy'}, None,
             raises(ValueError, match=r"region 'dummy' could not be parsed"))
        ]
    )
    def test_parse_region(self, kwargs: Dict, exp_output: SimpleRegion,
                          expectation: ContextManager) -> None:
        """Tests :func:`hal_gene_liftover.parse_region()` function.

        Args:
            kwargs: Named arguments to be passed to the function.
            exp_output: Expected return value of the function.
            expectation: Context manager for the expected exception, i.e. the test will only pass
                         if that exception is raised. Use :class:`~contextlib.nullcontext` if no
                         exception is expected.

        """
        with expectation:
            obs_output = hal_gene_liftover.parse_region(kwargs['region'])
            assert obs_output == exp_output

    @pytest.mark.parametrize(
        "kwargs, expectation",
        [
            ({'regions': [SimpleRegion('chr1', 15, 18, '+')],
              'bed_file': 'a2b.one2one.plus.flank0.src.bed', 'flank_length': 0}, does_not_raise()),
            ({'regions': [SimpleRegion('chr1', 15, 18, '+')],
              'bed_file': 'a2b.one2one.plus.flank1.src.bed', 'flank_length': 1}, does_not_raise()),
            ({'regions': [SimpleRegion('chr1', 15, 18, '-')],
              'bed_file': 'a2b.one2one.minus.flank0.src.bed', 'flank_length': 0}, does_not_raise()),
            ({'regions': [SimpleRegion('chr1', 15, 18, '-')],
              'bed_file': 'a2b.one2one.minus.flank1.src.bed', 'flank_length': 1}, does_not_raise()),
            ({'regions': [SimpleRegion('chr1', 22, 25, '+')],
              'bed_file': 'b2a.one2one.plus.flank0.src.bed', 'flank_length': 0}, does_not_raise()),
            ({'regions': [SimpleRegion('chr1', 22, 25, '+')],
              'bed_file': 'b2a.one2one.plus.flank1.src.bed', 'flank_length': 1}, does_not_raise()),
            ({'regions': [SimpleRegion('chr1', 22, 25, '-')],
              'bed_file': 'b2a.one2one.minus.flank0.src.bed', 'flank_length': 0}, does_not_raise()),
            ({'regions': [SimpleRegion('chr1', 22, 25, '-')],
              'bed_file': 'b2a.one2one.minus.flank1.src.bed', 'flank_length': 1}, does_not_raise()),
            ({'regions': [SimpleRegion('chr1', 6, 8, '+')],
              'bed_file': 'a2b.one2many.flank0.src.bed', 'flank_length': 0}, does_not_raise()),
            ({'regions': [SimpleRegion('chr1', 6, 8, '+')],
              'bed_file': 'a2b.one2many.flank1.src.bed', 'flank_length': 1}, does_not_raise()),
            ({'regions': [SimpleRegion('chr1', 26, 32, '+')],
              'bed_file': 'a2b.inversion.flank0.src.bed', 'flank_length': 0}, does_not_raise()),
            ({'regions': [SimpleRegion('chr1', 26, 32, '+')],
              'bed_file': 'a2b.inversion.flank1.src.bed', 'flank_length': 1}, does_not_raise()),
            ({'regions': [SimpleRegion('chr1', 15, 18, '+')],
              'bed_file': 'a2b.negative_flank.src.bed', 'flank_length': -1},
             raises(ValueError, match=r"'flank_length' must be greater than or equal to 0: -1")),

        ]
    )
    def test_make_src_region_file(self, kwargs: Dict, expectation: ContextManager,
                                  tmp_dir: Path) -> None:
        """Tests :func:`hal_gene_liftover.make_src_region_file()` function.

        Args:
            kwargs: Named arguments to be passed to the function.
            expectation: Context manager for the expected exception, i.e. the test will only pass
                         if that exception is raised. Use :class:`~contextlib.nullcontext` if no
                         exception is expected.
            tmp_dir: Unit test temp directory (fixture).

        """
        with expectation:
            out_file_path = tmp_dir / kwargs['bed_file']
            hal_gene_liftover.make_src_region_file(kwargs['regions'], out_file_path,
                                                   kwargs['flank_length'])
            ref_file_path = self.ref_file_dir / kwargs['bed_file']
            assert filecmp.cmp(out_file_path, ref_file_path)
