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
"""Unit testing of :mod:`config` module.

The unit testing is divided into one test class per submodule/class found in this module, and one test method
per public function/class method.

Typical usage example::

    $ pytest test_mlss_species_set_adaptor.py

"""

from contextlib import nullcontext as does_not_raise
from ensembl.compara.config import get_species_set_by_name
import os
import pytest
from pytest import raises
from typing import ContextManager, List
from xml.etree import ElementTree



@pytest.mark.parametrize(
    "mlss_conf_file, species_set_name, exp_output, expectation",
    [
        ("mlss_conf_simple.xml", "test1", ["danio_rerio", "gallus_gallus", "homo_sapiens", "mus_musculus", "strigamia_maritima"], does_not_raise()),
        ("mlss_conf_simple.xml", "test3", ["", "gallus_gallus", "homo_sapiens"], does_not_raise()),
        ("mlss_conf_simple.xml", "", ["danio_rerio", "mus_musculus"], does_not_raise()),
        ("mlss_conf_simple.xml", "test4", [], does_not_raise()),
        ("mlss_conf_realistic.xml", "default", ["drosophila_melanogaster", "caenorhabditis_elegans", "saccharomyces_cerevisiae"], does_not_raise()),
        ("mlss_conf_realistic.xml", "murinae", [], does_not_raise()),
        ("fake/path/mlss_simple.xml", "test", None, raises(FileNotFoundError)),
        ("mlss_conf_not_xml.xml", "test", None, raises(ElementTree.ParseError)),
        ("mlss_conf_simple.xml", "test", None, raises(NameError, match=r"Species set 'test' not found.")),
        ("mlss_conf_simple.xml", "test2", None, raises(RuntimeError, match=r"2 species sets named 'test2' found."))
    ]
)
def test_get_species_set_by_name(mlss_conf_file: str, species_set_name: str, exp_output: List[str],
                                 expectation: ContextManager) -> None:
    """Tests :func:`config.get_species_set_by_name()` function.

    Args:
        mlss_conf_file: MLSS configuration XML file to be parsed.
        species_set_name: Species set (collection) name.
        exp_output: Expected return value of the function.
        expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

    """
    mlss_conf_path = pytest.files_dir / 'config' / mlss_conf_file
    with expectation:
        assert get_species_set_by_name(mlss_conf_path, species_set_name) == exp_output
