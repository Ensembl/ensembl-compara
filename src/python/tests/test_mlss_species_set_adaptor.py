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

import os
from contextlib import nullcontext as does_not_raise
from typing import ContextManager, List
from xml.etree import ElementTree

import pytest
from pytest import param, raises

from ensembl.compara.config import get_species_set_by_name

test_files_dir = os.path.join(os.path.dirname(__file__), "flatfiles/config/")

@pytest.mark.parametrize(
    "file, name, exp_output, expectation",
    [
        ("mlss_conf1.xml", "test1", ["danio_rerio", "gallus_gallus", "homo_sapiens", "mus_musculus", "strigamia_maritima"], does_not_raise()),
        ("mlss_conf1.xml", "test3", ["", "gallus_gallus", "homo_sapiens"], does_not_raise()),
        ("mlss_conf1.xml", "", ["danio_rerio", "mus_musculus"], does_not_raise()),
        ("mlss_conf1.xml", "test4", [], does_not_raise()),
        ("mlss_conf2.xml", "default", ["drosophila_melanogaster", "caenorhabditis_elegans", "saccharomyces_cerevisiae"], does_not_raise()),
        ("mlss_conf2.xml", "murinae", [], does_not_raise()),
        ("fake/path/mlss_conf1.xml", "test", None, raises(FileNotFoundError, match=r"mlss_conf file not found.")),
        ("mlss_conf3.xml", "test", None, raises(ElementTree.ParseError)),
        ("mlss_conf1.xml", "test", None, raises(NameError, match=r"Species set test not found.")),
        ("mlss_conf1.xml", "test2", None, raises(NameError, match=r"2 species sets named test2 found."))
    ]
)

def test_get_species_set_by_name(file: str, name: str, exp_output: List[str], expectation: ContextManager) -> None:
    """Tests :func:`config.get_species_set_by_name()` function.

    Args:
        file: Path to the XML file to be parsed.
        name: Species set (collection) name.
        exp_output: Expected return value of the method.
        expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

    """
    with expectation:
        assert get_species_set_by_name(os.path.join(test_files_dir, file), name) == exp_output, "List returned differs from the one expected."
