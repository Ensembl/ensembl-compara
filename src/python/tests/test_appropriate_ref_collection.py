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
"""Unit testing of `appropriate_ref_collection.py` script.

Typical usage example::

    $ pytest test_appropriate_ref_collection.py

"""

from contextlib import nullcontext as does_not_raise
from pathlib import Path
from os.path import isdir
import subprocess
from subprocess import CalledProcessError
from typing import ContextManager, List

import pytest
from pytest import raises

from ensembl.utils.database import UnitTestDB


@pytest.mark.parametrize("test_dbs", [[{"src": "ncbi_db"}]], indirect=True)
class TestAppropriateRefCollection:
    """Tests `appropriate_ref_collection.py` script.

    Attributes:
        dbc (DBConnection): Database connection to the unit test database.
        dir (ptest.files_dir): Test files directory.
        script: Path to `appropriate_ref_collection.py`

    """

    dbc: UnitTestDB = None

    @pytest.fixture(scope="class", autouse=True)
    def setup(self, test_dbs: dict[str, UnitTestDB]) -> None:
        """Loads the required fixtures and values as class attributes.

        Args:
            test_dbs: Unit test databases (fixture).
        """
        type(self).dbc = test_dbs["ncbi_db"].dbc
        # pylint: disable=no-member
        type(self).dir = pytest.files_dir / "ref_taxa" # type: ignore
        # pylint: disable=no-member
        type(self).script = ( # type: ignore
            Path(__file__).parents[3] / "scripts" / "pipeline" / "appropriate_ref_collection.py"
        )

    @pytest.mark.parametrize(
        "species, params, exp_stdout, expectation",
        [
            (
                "canis_lupus_familiaris",
                ["--taxon_name", "--ref_base_dir", "--url"],
                "mammalia",
                does_not_raise(),
            ),
            (
                "gallus_gallus",
                ["--taxon_name", "--ref_base_dir", "--url"],
                "vertebrata",
                does_not_raise(),
            ),
            (
                "gallus_gallus",
                ["--taxon_name", "--url"],
                "A valid --taxon_name, --ref_base_dir and --url are required",
                raises(CalledProcessError),
            ),
            (
                "gallus_gallus",
                ["--ref_base_dir", "--url"],
                "A valid --taxon_name, --ref_base_dir and --url are required",
                raises(CalledProcessError),
            ),
            (
                "gallus_gallus",
                ["--taxon_name", "--ref_base_dir"],
                "A valid --taxon_name, --ref_base_dir and --url are required",
                raises(CalledProcessError),
            ),
            (
                "chocolate_chip_cookie",
                ["--taxon_name", "--ref_base_dir", "--url"],
                "A valid --taxon_name, --ref_base_dir and --url are required",
                raises(CalledProcessError),
            ),
        ],
    )
    def test_appropriate_ref_collection(
        self, species: str, params: List[str], exp_stdout: str, expectation: ContextManager,
    ) -> None:
        """Tests the appropriate_ref_collection.py script as a whole.

        Args:
            species: A genome or taxon name.
            params: Necessary arguments to run the appropriate_ref_collection script.
            exp_stdout: Expected directory base name
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.
        """
        # pylint: disable=no-member
        script = str(self.script) # type: ignore
        cmd_opts = {
            "--taxon_name": species,
            "--ref_base_dir": Path(self.dir), # type: ignore
            "--url": self.dbc.url,
        }
        filtered_opts = {param: cmd_opts[param] for param in params}
        opts = [f"{k} {v}" for k, v in filtered_opts.items()]
        cmd = str('python' + ' ' + script + ' ' + ' '.join(opts))
        with expectation:
            output = subprocess.check_output(cmd, shell=True).decode().strip()
            if isdir(output):
                # pylint: disable=no-member
                assert output == f"{self.dir}/{exp_stdout}" # type: ignore[attr-defined]
            else:
                assert output == exp_stdout
