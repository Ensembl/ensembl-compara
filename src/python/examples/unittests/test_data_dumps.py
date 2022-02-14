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
"""Unit testing of `data_dumps.py` script.

Typical usage example::

    $ pytest test_data_dumps.py

"""

from contextlib import nullcontext as does_not_raise
from importlib.abc import Loader
from importlib.machinery import ModuleSpec
from importlib.util import module_from_spec, spec_from_file_location
import os
from pathlib import Path
import sys
from typing import ContextManager, Dict, List

import sqlalchemy

import pytest

from ensembl.compara.filesys import file_cmp


script_path = Path(__file__).parents[3] / "scripts" / "pipeline" / "data_dumps.py"
script_name = script_path.stem
script_spec = spec_from_file_location(script_name, script_path)

if not isinstance(script_spec, ModuleSpec):
    raise ImportError(f"ModuleSpec not created for module file '{script_path}'")
if not isinstance(script_spec.loader, Loader):
    raise ImportError(f"no loader found for module file '{script_path}'")

data_dumps_module = module_from_spec(script_spec)
sys.modules[script_name] = data_dumps_module
script_spec.loader.exec_module(data_dumps_module)

# pylint: disable=import-error,wrong-import-order,wrong-import-position

import data_dumps  # type: ignore

# pylint: enable=import-error,wrong-import-order,wrong-import-position

def test_find_latest_core_naive() -> None:
    """Tests :func:`data_dumps.find_latest_core()` function when it does not raise an error.

    Args:
        core_names: A list of core database names.

    """
    core_names = ["mus_musculus_core_105_1", "mus_musculus_core_52_105_3", "mus_musculus_core_104_4"]
    assert data_dumps.find_latest_core(core_names) == "mus_musculus_core_52_105_3"


def test_find_latest_core_naive_error() -> None:
    """Tests :func:`data_dumps.find_latest_core()` function when it raises an error.

    Args:
        core_names: A list of core database names.

    """
    with pytest.raises(ValueError):
        data_dumps.find_latest_core([])


@pytest.mark.parametrize(
    "core_names, exp_output, expectation",
    [
        (["mus_musculus_core_105_1", "mus_musculus_core_52_105_3", "mus_musculus_core_104_4"],
         "mus_musculus_core_52_105_3", does_not_raise()),
        ([], None, pytest.raises(ValueError))
    ]
)
def test_find_latest_core(core_names: List[str], exp_output: str, expectation: ContextManager) -> None:
    """Tests :func:`data_dumps.find_latest_core()` function.

    Args:
        core_names: A list of core database names.
        exp_output: Expected return value of the function.
        expectation: Context manager for the expected exception, i.e. the test will only pass if that
            exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

    """
    with expectation:
        assert data_dumps.find_latest_core(core_names) == exp_output


@pytest.mark.parametrize(
    "multi_dbs",
    [
        [{'src': 'core/gallus_gallus_core_99_6'}, {'src': 'core/homo_sapiens_core_99_38'}]
    ],
    indirect=True
)
class TestDumpGenomes:
    """Tests :func:`data_dumps.dump_genomes()` function.

    Attributes:
        core_dbs: A set of test core databases.
        host: Host of the test database server.
        port: Port of the test database server.
        username: Username to access the test `host:port`

    """

    core_dbs = {}  # type: Dict
    host = None  # type: str
    port = None  # type: int
    username = None  # type: str

    # autouse=True makes this fixture be executed before any test_* method of this class, and scope='class'
    # to execute it only once per class parametrization
    @pytest.fixture(scope='class', autouse=True)
    def setup(self, request: pytest.FixtureRequest, multi_dbs: Dict) -> None:
        """Loads the required fixtures and values as class attributes.

        Args:
            request: Access to the requesting test context.
            multi_dbs: Dictionary of unit test databases (fixture).

        """
        type(self).core_dbs = multi_dbs
        server_url = sqlalchemy.engine.url.make_url(request.config.getoption('server'))
        type(self).host = server_url.host
        type(self).port = server_url.port
        type(self).username = "ensro" if server_url.username == "ensadmin" else server_url.username

    @pytest.mark.skipif(os.environ['USER'] == 'travis',
                        reason="The test requires both Perl and Python which is not supported by Travis.")
    @pytest.mark.parametrize(
        "core_list, species_set_name, id_type, expectation",
        [
            (
                [f"{os.environ['USER']}_gallus_gallus_core_99_6",
                 f"{os.environ['USER']}_homo_sapiens_core_99_38"],
                "vertebrates", "protein", does_not_raise()
            ),
            ([], "test", "gene", pytest.raises(ValueError))
        ]
    )
    def test_dump_genomes(self, core_list: List[str], species_set_name: str,
                          tmp_dir: Path, id_type: str, expectation: ContextManager) -> None:
        """Tests :func:`data_dumps.dump_genomes()` when server connection can be established.

        Args:
            core_list: A list of core db names.
            species_set_name: Species set (collection) name.
            tmp_dir: Unit test temp directory (fixture).
            id_type: Type of identifier to use in the dumps.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

        """
        with expectation:
            data_dumps.dump_genomes(core_list, species_set_name, self.host, self.port, tmp_dir,
                                             id_type)

            out_files = tmp_dir / species_set_name
            # pylint: disable-next=no-member
            exp_out = pytest.files_dir / "dump_genomes"  # type: ignore[attr-defined]
            for db_name, unittest_db in self.core_dbs.items():
                assert file_cmp(out_files / f"{unittest_db.dbc.db_name}.fasta", exp_out / f"{db_name}.fasta")

    def test_dump_genomes_fake_connection(self, tmp_dir: Path) -> None:
        """Tests :func:`data_dumps.dump_genomes()` with fake server details.

        Args:
            tmp_dir: Unit test temp directory (fixture).

        """
        with pytest.raises(RuntimeError):
            data_dumps.dump_genomes(["mus_musculus", "naja_naja"], "fake",
                                             "fake-host", 65536, tmp_dir, "protein")

    def test_dump_genomes_fake_output_path(self) -> None:
        """Tests :func:`data_dumps.dump_genomes()` with fake output path."""
        with pytest.raises(OSError):
            data_dumps.dump_genomes(["mus_musculus", "naja_naja"], "default",
                                             self.host, self.port, "/nonexistent/path", "protein")
