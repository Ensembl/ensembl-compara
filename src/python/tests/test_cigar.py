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

from typing import Tuple, ContextManager, List
from contextlib import nullcontext as does_not_raise

import pytest

from ensembl.compara.utils import aligned_seq_to_cigar, get_cigar_array, alignment_to_seq_coordinate


class TestCigar:
    """Tests :mod:`tools` submodule."""

    @pytest.mark.parametrize(
        "aligned_seq, cigar",
        [
            ("ATGCATTGAT---ATTTA--AT", "M10D3M5D2M2"),
            ("A-T-GCA--T-TGAT---ATTTA--AT", "MDMDM3D2MDM4D3M5D2M2"),
            ("ATGCATTGATATTTAAT", "M17"),
            ("-----------------", "D17"),
            ("-ATGCATTGATATTTAAT", "DM17"),
            ("ATGCATTGATATTTAAT-", "M17D"),
            ("--ATGCATTGATATTTAAT", "D2M17"),
            ("ATGCATTGATATTTAAT--", "M17D2")
        ],
    )
    def test_aligned_seq_to_cigar(self, aligned_seq: str, cigar: str) -> None:
        """Tests :meth:`cigar.aligned_seq_to_cigar()` method.

        Args:
            aligned_seq: aligned sequence (str).
            cigar: Expected cigar line (str).

        """
        assert aligned_seq_to_cigar(aligned_seq) == cigar, "cigar line returned differs from the one expected"

    @pytest.mark.parametrize(
        "cigar, cigar_array",
        [
            ("M10D3M5D2M2", [("M", 10), ("D", 3), ("M", 5), ("D", 2), ("M", 2)]),
            ("MDMDM3D2", [("M", 1), ("D", 1), ("M", 1), ("D", 1), ("M", 3), ("D", 2)]),
            ("M17",[("M", 17)]),
            ("D17",[("D", 17)])
        ],
    )
    def test_get_cigar_array(self, cigar: str, cigar_array: List[Tuple]) -> None:
        """Tests :meth:`cigar.aligned_seq_to_cigar()` method.

            Args:
                cigar: cigar line (str).
                cigar_array: Expected cigar array (List[Tuple])
        """
        assert get_cigar_array(cigar) == cigar_array, "cigar line returned differs from the one expected"


    @pytest.mark.parametrize(
        "cigar, coord_align, coord_seq, expectation",
        [
            ("M10D3M5D2M2", 21, 16, does_not_raise()),
            ("M10D3M5D2M2", 12, 10, does_not_raise()),
            ("M10D3M5D2M2", 13, 10, does_not_raise()),
            ("M10D3M5D2M2", 11, 10, does_not_raise()),
            ("M10D3M5D2M2", 19, 15, does_not_raise()),
            ("M10D3M5D2M2", 20, 15, does_not_raise()),
            ("M10D3M5D2M2", 20, 15, does_not_raise()),
            ("D17",15, 0, does_not_raise()),
            ("M17", 15, 15, does_not_raise()),
            ("M10D3M5D2M2", 30, None, pytest.raises(ValueError)),
            ("M10D3M5D2M2", 0, None, pytest.raises(ValueError)),
            ("M10D3M5D2M2", -4, None, pytest.raises(ValueError))
        ],
    )
    def test_alignment_to_seq_coordinate(self, cigar: str, coord_align: int,
                                         coord_seq: int, expectation: ContextManager) -> None:
        """Tests :meth:`cigar.alignment_to_seq_coordinate()` method.

            Args:
                cigar: cigar line (str).
                coord_align: Coordinate at the alignment level (int)
                coord_seq:
        """
        error = "difference of coord_seq compared tot he one expected with  coord_align"
        with expectation:
            assert alignment_to_seq_coordinate(cigar, coord_align) == coord_seq, error
