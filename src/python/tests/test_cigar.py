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
"""Unit testing of :mod:`cigar` module.

Typical usage example::

    $ pytest test_cigar.py

"""

from contextlib import nullcontext as does_not_raise
from typing import Tuple, ContextManager, List

import pytest

from ensembl.compara.utils import aligned_seq_to_cigar, alignment_to_seq_coordinate, get_cigar_array


class TestCigar:
    """Tests :mod:`cigar` submodule."""

    @pytest.mark.parametrize(
        "aligned_seq, cigar",
        [
            ("ATGCATTGAT---ATTTA--AT", "10M3D5M2D2M"),
            ("A-T-GCA--T-TGAT---ATTTA--AT", "MDMD3M2DMD4M3D5M2D2M"),
            ("ATGCATTGATATTTAAT", "17M"),
            ("-----------------", "17D"),
            ("-ATGCATTGATATTTAAT", "D17M"),
            ("ATGCATTGATATTTAAT-", "17MD"),
            ("--ATGCATTGATATTTAAT", "2D17M"),
            ("ATGCATTGATATTTAAT--", "17M2D")
        ],
    )
    def test_aligned_seq_to_cigar(self, aligned_seq: str, cigar: str) -> None:
        """Tests :func:`cigar.aligned_seq_to_cigar()` function.

        Args:
            aligned_seq: aligned sequence.
            cigar: Expected cigar line.

        """
        assert aligned_seq_to_cigar(aligned_seq) == cigar, "cigar line returned differs from the one expected"

    @pytest.mark.parametrize(
        "cigar, cigar_array",
        [
            ("10M3D5M2D2M", [(10, "M"), (3, "D"), (5, "M"), (2, "D"), (2, "M")]),
            ("MDMD3M2D", [(1, "M"), (1, "D"), (1, "M"), (1, "D"), (3, "M"), (2, "D")]),
            ("17M", [(17, "M")]),
            ("17D", [(17, "D")])
        ],
    )
    def test_get_cigar_array(self, cigar: str, cigar_array: List[Tuple]) -> None:
        """Tests :func:`cigar.aligned_seq_to_cigar()` function.

            Args:
                cigar: cigar line.
                cigar_array: Expected cigar array.
        """
        assert get_cigar_array(cigar) == cigar_array, "cigar list returned differs from the one expected"


    @pytest.mark.parametrize(
        "cigar, coord_align, coord_seq, expectation",
        [
            ("10M3D5M2D2M", 21, [16], does_not_raise()),
            ("10M3D5M2D2M", 12, [10, 11], does_not_raise()),
            ("10M3D5M2D2M", 13, [10, 11], does_not_raise()),
            ("10M3D5M2D2M", 11, [10, 11], does_not_raise()),
            ("17D", 15, [0, 1], does_not_raise()),
            ("17M", 15, [15], does_not_raise()),
            ("10M3D5M2D2M", 30, None, pytest.raises(ValueError)),
            ("10M3D5M2D2M", 0, None, pytest.raises(ValueError)),
            ("10M3D5M2D2M", -4, None, pytest.raises(ValueError))
        ],
    )
    def test_alignment_to_seq_coordinate(self, cigar: str, coord_align: int,
                                         coord_seq: int, expectation: ContextManager) -> None:
        """Tests :func:`cigar.alignment_to_seq_coordinate()` function.

            Args:
                cigar: cigar line.
                coord_align: Coordinate at the alignment level.
                coord_seq: expected coordinate at the sequence level
                expectation: Context manager for the expected exception, i.e. the test will only pass if that
                    exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.
        """
        error = "difference of coord_seq compared to the one expected with coord_align"
        with expectation:
            assert alignment_to_seq_coordinate(cigar, coord_align) == coord_seq, error