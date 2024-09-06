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
"""Unit testing of `repair_mlss_tags.py` script.

Typical usage example::

    $ pytest test_repair_mlss_tags.py

"""

from contextlib import nullcontext as does_not_raise
from pathlib import Path
import subprocess
from typing import ContextManager, Dict, List, Set

import pytest

from ensembl.utils.database import DBConnection, UnitTestDB


@pytest.mark.parametrize("test_dbs", [{'src': 'pan'}], indirect=True)
class TestRepairMLSSTags:
    """Tests `repair_mlss_tags.py` script.

    Attributes:
        dbc (DBConnection): Database connection to the unit test database.

    """

    dbc = None  # type: DBConnection

    # autouse=True makes this fixture be executed before any test_* method of this class, and scope='class' to
    # execute it only once per class parametrization
    @pytest.fixture(scope='class', autouse=True)
    def setup(self, test_dbs: UnitTestDB) -> None:
        """Loads the required fixtures and values as class attributes.

        Args:
            test_dbs: Unit test database (fixture).

        """
        # Use type(self) instead of self as a workaround to @classmethod decorator (unsupported by pytest and
        # required when scope is set to "class" <https://github.com/pytest-dev/pytest/issues/3778>)
        type(self).dbc = test_dbs.dbc

    @pytest.mark.parametrize(
        "mlss_tag, alt_queries, exp_stdout, exp_tag_value, expectation",
        [
            ('', [], set(['No repair option has been selected: Nothing to do']), {}, does_not_raise()),
            ('max_align', [], set(['']),
             {1: 161, 2: 163, 3: 139, 4: 52068, 5: 2452, 6: 37683, 7: 13002, 8: 825240, 9: 996143, 10: 9708},
             does_not_raise()),
            ('msa_mlss_id', [], set(['']), {5: 4, 7: 6, 9: 8, 50001: 4, 50002: 6, 50003: 8},
             does_not_raise()),
            (
                'max_align',
                [
                    "UPDATE method_link_species_set_tag SET value = 1 "
                        "WHERE method_link_species_set_id = 2 AND tag = 'max_align'",
                    "DELETE FROM method_link_species_set_tag "
                        "WHERE method_link_species_set_id = 6 AND tag = 'max_align'",
                    "INSERT INTO method_link_species_set_tag VALUES (404, 'max_align', 1)"
                ],
                set([
                    "Repaired MLSS tag 'max_align' for MLSS id '2'",
                    "Added missing MLSS tag 'max_align' for MLSS id '6'",
                    "Deleted unexpected MLSS tag 'max_align' for MLSS id '404'"
                ]),
                {1: 161, 2: 163, 3: 139, 4: 52068, 5: 2452, 6: 37683, 7: 13002, 8: 825240, 9: 996143,
                 10: 9708},
                does_not_raise()
            ),
            (
                'msa_mlss_id',
                [
                    "UPDATE method_link_species_set_tag SET value = 1 "
                        "WHERE method_link_species_set_id = 5 AND tag = 'msa_mlss_id'",
                    "DELETE FROM method_link_species_set_tag "
                        "WHERE method_link_species_set_id = 50001 AND tag = 'msa_mlss_id'",
                    "INSERT INTO method_link_species_set_tag VALUES (404, 'msa_mlss_id', 1)"
                ],
                set([
                    "Repaired MLSS tag 'msa_mlss_id' for MLSS id '5'",
                    "Added missing MLSS tag 'msa_mlss_id' for MLSS id '50001'",
                    "Deleted unexpected MLSS tag 'msa_mlss_id' for MLSS id '404'"
                ]),
                {5: 4, 7: 6, 9: 8, 50001: 4, 50002: 6, 50003: 8},
                does_not_raise()
            ),
        ]
    )
    def test_repair_mlss_tag(self, mlss_tag: str, alt_queries: List[str], exp_stdout: Set[str],
                             exp_tag_value: Dict[int, int], expectation: ContextManager) -> None:
        """Tests `repair_mlss_tags.py` script, including its output.

        Args:
            mlss_tags: MLSS tag as found in the ``method_link_species_set_tag`` table.
            alt_queries: MySQL queries to alter the content of the database before running the test.
            exp_stdout: Expected messages printed in STDOUT.
            exp_tag_value: Expected MLSS id - value pairs for the given `mlss_tag` after the script is run.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

        """
        # Alter the MLSS tags table so there is something to repair
        with self.dbc.connect() as connection:
            connection.execute("SET FOREIGN_KEY_CHECKS = 0")
            for sql in alt_queries:
                connection.execute(sql)
            connection.execute("SET FOREIGN_KEY_CHECKS = 1")
        # Run the repair_mlss_tags.py command
        cmd = [str(Path(__file__).parents[3] / 'scripts' / 'production' / 'repair_mlss_tags.py'),
               '--url', self.dbc.url]
        if mlss_tag:
            cmd.append(f'--{mlss_tag}')
        with expectation:
            # Check the information printed in STDOUT is as expected
            output = subprocess.check_output(cmd)
            assert set(output.decode().strip().split("\n")) == exp_stdout
            if exp_tag_value:
                # Check the database has the expected information
                with self.dbc.connect() as connection:
                    result = connection.execute(f"SELECT method_link_species_set_id AS mlss_id, value "
                                                f"FROM method_link_species_set_tag WHERE tag = '{mlss_tag}'")
                    curr_tag_value = {row.mlss_id: int(row.value) for row in result.fetchall()}
                    assert curr_tag_value == exp_tag_value
