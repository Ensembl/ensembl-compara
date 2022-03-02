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
"""Unit testing of `appropriate_ref_collection_fasta.py` script.

Typical usage example::

    $ pytest test_appropriate_ref_collection_fasta.py

"""

from contextlib import nullcontext as does_not_raise
from pathlib import Path
import subprocess
from typing import ContextManager, List

import pytest

from ensembl.database import UnitTestDB


@pytest.mark.parametrize("db", [{"src": "ncbi_db"}], indirect=True)
class TestAppropriateRefCollectionFasta:
    """Tests `appropriate_ref_collection_fasta.py` script.

    Attributes:
        dbc (DBConnection): Database connection to the unit test database.
        dir (ptest.files_dir): Test files directory.
        script: Path to `appropriate_ref_collection_fasta.py`

    """

    dbc = None  # type: UnitTestDB

    @pytest.fixture(scope="class", autouse=True)
    def setup(self, db: UnitTestDB) -> None:
        """Loads the required fixtures and values as class attributes.

        Args:
            db: Generator of unit test database (fixture).
        """
        type(self).dbc = db.dbc
        # pylint: disable=no-member
        type(self).dir = pytest.files_dir / "ref_taxa" # type: ignore
        # pylint: disable=no-member
        type(self).fasta_dir = pytest.files_dir / "genome_fasta" # type: ignore
        # pylint: disable=no-member
        type(self).script = ( # type: ignore
            Path(__file__).parents[3] / "scripts" / "pipeline" / "appropriate_ref_collection_fasta.py"
        )

    @pytest.mark.parametrize(
        "species, params, exp_stdout, expectation",
        [
            (
                "canis_lupus_familiaris",
                ["--taxon_name", "--genome_fasta", "--dest_dir", "--comparators_dir", "--url"],
                "['abc.fasta', 'canis_lupus_familiaris.fasta']",
                does_not_raise(),
            ),
            (
                "Canis_lupus_familiaris",
                ["--taxon_name", "--genome_fasta", "--dest_dir", "--comparators_dir", "--url"],
                "Unable to copy Canis_lupus_familiaris.fasta to destination",
                does_not_raise(),
            ),
            (
                "gallus_gallus",
                ["--taxon_name", "--genome_fasta", "--dest_dir", "--comparators_dir"],
                "A valid --taxon_name, --genome_fasta, --dest_dir, --comparators_dir and --url are required",
                does_not_raise(),
            ),
            (
                "gallus_gallus",
                ["--taxon_name", "--genome_fasta", "--dest_dir", "--url"],
                "A valid --taxon_name, --genome_fasta, --dest_dir, --comparators_dir and --url are required",
                does_not_raise(),
            ),
            (
                "gallus_gallus",
                ["--taxon_name", "--genome_fasta", "--comparators_dir", "--url"],
                "A valid --taxon_name, --genome_fasta, --dest_dir, --comparators_dir and --url are required",
                does_not_raise(),
            ),
            (
                "gallus_gallus",
                ["--taxon_name", "--dest_dir", "--comparators_dir", "--url"],
                "A valid --taxon_name, --genome_fasta, --dest_dir, --comparators_dir and --url are required",
                does_not_raise(),
            ),
            (
                "gallus_gallus",
                ["--genome_fasta", "--dest_dir", "--comparators_dir", "--url"],
                "A valid --taxon_name, --genome_fasta, --dest_dir, --comparators_dir and --url are required",
                does_not_raise(),
            ),
            (
                "chocolate_chip_cookie",
                ["--genome_fasta", "--dest_dir", "--comparators_dir", "--url"],
                "A valid --taxon_name, --genome_fasta, --dest_dir, --comparators_dir and --url are required",
                does_not_raise(),
            ),
            (
                "",
                ["--genome_fasta", "--dest_dir", "--comparators_dir", "--url"],
                "A valid --taxon_name, --genome_fasta, --dest_dir, --comparators_dir and --url are required",
                does_not_raise(),
            ),
        ],
    )
    def test_appropriate_ref_collection_fasta(
        self, species: str, params: List[str], tmp_dir: Path, exp_stdout: str, expectation: ContextManager,
    ) -> None:
        """Tests the appropriate_ref_collection_fasta.py script as a whole.

        Args:
            species: A genome or taxon name.
            params: Necessary arguments to run the appropriate_ref_collection_fasta script.
            tmp_dir: Unit test temp directory (fixture).
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.
        """
        # pylint: disable=no-member
        fasta_name = species + ".fasta" # type: ignore
        genome_fasta = Path(self.fasta_dir, fasta_name) # type: ignore
        dest_dir = tmp_dir / "query_set" # type: ignore[attr-defined,operator]
        print(dest_dir)
        # pylint: disable=no-member
        script = str(self.script) # type: ignore
        cmd_opts = {
            "--taxon_name": species,
            "--genome_fasta": genome_fasta,
            "--dest_dir": dest_dir,
            "--comparators_dir": Path(self.dir), # type: ignore
            "--url": self.dbc.url,
        }
        filtered_opts = {param: cmd_opts[param] for param in params}
        opts = [f"{k} {v}" for k, v in filtered_opts.items()]
        cmd = str('python' + ' ' + script + ' ' + ' '.join(opts))
        with expectation:
            output = subprocess.check_output(cmd, shell=True).decode().strip()
            assert output == exp_stdout
