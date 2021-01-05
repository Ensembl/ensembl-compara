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
"""Unit testing of :mod:`utils` module.

The unit testing is divided into one test class per submodule/class found in this module, and one test method
per public function/class method.

Typical usage example::

    $ pytest test_utils.py

"""

from typing import Any, List

import pytest

from ensembl.compara.utils import to_list


class TestTools:
    """Tests :mod:`tools` submodule."""

    @pytest.mark.parametrize(
        "arg, output",
        [
            (None, []),
            ('', []),
            (0, []),
            ('a', ['a']),
            (['a', 'b'], ['a', 'b'])
        ],
    )
    def test_file_cmp(self, arg: Any, output: List[Any]) -> None:
        """Tests :meth:`tools.to_list()` method.

        Args:
            arg: Element to be converted to a list.
            output: Expected returned list.

        """
        assert to_list(arg) == output, "List returned differs from the one expected"
