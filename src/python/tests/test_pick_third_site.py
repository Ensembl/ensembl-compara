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
"""Testing of `pick_third_site.py` script.

Typical usage example::

    $ pytest collate_busco_results.py

"""

import sys
import subprocess
from pathlib import Path

from ensembl.compara.filesys import file_cmp


class TestPickThirdSite:
    """Tests for the `pick_third_site.py` script.
    """

    def test_pick_third_site(self, tmp_dir: Path) -> None:
        """Tests the output of `collate_busco_results.py` script.

        Args:
            tmp_dir: Unit test temp directory (fixture).
        """
        input_file = str(Path(__file__).parents[2] / 'test_data' /
                         'flatfiles' / 'SpeciesTreeFromBusco' / 'pick_third_site_input.fas')
        output_fas = str(tmp_dir / "pick_third_site_output.fas")

        # Run the command

        cmd = [sys.executable, str(Path(__file__).parents[3] / 'pipelines' /
                                   'SpeciesTreeFromBusco' / 'scripts' / 'pick_third_site.py'),
               '-i', input_file, '-o', output_fas]
        location = str(Path(__file__).parents[0])
        subprocess.check_call(cmd, cwd=location)

        # Compare with expected output:
        expected_fas = str(Path(__file__).parents[2] / 'test_data' / "flatfiles" /
                           "SpeciesTreeFromBusco" / "pick_third_site_expected.fas")

        assert file_cmp(output_fas, expected_fas)
