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
"""Unit testing of `get_nearest_taxonomy.py` script.

Typical usage example::

    $ pytest test_get_nearest_taxonomy.py

"""

from contextlib import nullcontext as does_not_raise
from pathlib import Path
import subprocess
from subprocess import CalledProcessError
from typing import ContextManager, List

import pytest
from pytest import raises

from ensembl.utils.database import DBConnection, UnitTestDB


@pytest.mark.parametrize("test_dbs", [[{"src": "ncbi_db"}]], indirect=True)
class TestGetNearestTaxonomy:
    """Tests `get_nearest_taxonomy.py` script.

    Attributes:
        dbc (DBConnection): Database connection to the unit test database.
        script: Path to `get_nearest_taxonomy.py`

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
        type(self).script = (  # type: ignore
            Path(__file__).parents[3]
            / "scripts"
            / "pipeline"
            / "get_nearest_taxonomy.py"
        )

    @pytest.mark.parametrize(
        "params, exp_stdout, expectation",
        [
            (
                [
                    "--taxon_name",
                    "canis_lupus_familiaris",
                    "--taxon_list",
                    "vertebrata",
                    "mammalia",
                    "sauropsida",
                ],
                "mammalia",
                does_not_raise(),
            ),
            (
                ["--taxon_name", "gallus_gallus", "--taxon_list", "ctenophora"],
                "default",
                does_not_raise(),
            ),
            (
                [
                    "--taxon_name",
                    "potato_cake",
                    "--taxon_list",
                    "viridiplantae",
                    "default",
                ],
                "A valid --taxon_name, --taxon_list and --url are required",
                raises(CalledProcessError),
            ),
            (
                [],
                "A valid --taxon_name, --taxon_list and --url are required",
                raises(CalledProcessError),
            ),
        ],
    )
    def test_appropriate_ref_collection(
        self,
        params: List[str],
        exp_stdout: str,
        expectation: ContextManager,
    ) -> None:
        """Tests the get_nearest_taxonomy.py script as a whole.

        Args:
            params: Necessary arguments to run the get_nearest_taxonomy.py script.
            exp_stdout: Expected nearest taxonomic classification
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.
        """
        # pylint: disable=no-member
        script = str(self.script)  # type: ignore
        cmd = str(
            "python" + " " + script + " " + " ".join(params) + " " + "--url" + " " + self.dbc.url
        )
        with expectation:
            output = subprocess.check_output(cmd, shell=True).decode().strip()
            assert output == exp_stdout
