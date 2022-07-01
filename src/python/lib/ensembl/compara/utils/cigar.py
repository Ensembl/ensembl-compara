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
"""Collection of utils methods targeted to cigar line manipulation."""

__all__ = ['aligned_seq_to_cigar', 'alignment_to_seq_coordinate',
           'get_cigar_array', 'alignment_to_seq_region']

from typing import List, Tuple, Optional

def alignment_to_seq_region(cigar: str, start: int, end: int) -> Optional[Tuple[int,int]]:
    """Convert the coordinate of a region from the alignment level to the unaligned seq level

         An ungapped with a start and an end in a non-gaped area will return a direct coordinate mapping i.e
         the region with a start = 3 and an end = 12 in the aligned sequence below will return (3,7).
         A region with start and end in the single gap opening will return an empty pair as the region
         does not exist in this sequence, i.e a region with start=5 and end=8 will return ()
         A region with a start in a gap opening will return the first position after the gap closes whether
         the end is in an alternative gapped or ungapped position ie start = 6 and end = 14 will return (5,9).
         A region with an end in a gap will return the last position before the gap whether the start is
         in an ungapped or alternative gap position. i.e start = 6 and end = 20 will return (5,9)

        aligned:     1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26
                     A  A  T  C  -  -  -  -  -  A  C  T  C  T  -  -  -  -  -  -  -  -  T  C  T  C
        unaligned:   1  2  3  4                 5  6  7  8  9                          10 11 12 13


        Args:
            cigar: cigar line of the aligned sequence
            start: start coordinate of the region in the alignment
            end: end coordinate of the region in the alignment
        Returns:
            coordinate of the unaligned region at the sequence level, empty tuple if the region is
            inside a gap
        Raises:
            AssertionError : if start >= end
a         """
    ## test precondition for this function
    assert start < end, f"error start: {start} is not smaller than end: {end}"

    result = ()
    ce_seq_start = alignment_to_seq_coordinate(cigar, start)
    ce_seq_end = alignment_to_seq_coordinate(cigar, end)

    if len(ce_seq_start) == 1 and len(ce_seq_end) == 1:  # two position in a non gapped area
        result = (int(ce_seq_start[0]), int(ce_seq_end[0]))
    elif len(ce_seq_start) == 1 and len(ce_seq_end) == 2:  # start in non gapped, end in gapped
        result = (int(ce_seq_start[0]), int(ce_seq_end[0]))
    elif len(ce_seq_start) == 2 and len(ce_seq_end) == 1:  # start in gapped, end in non gapped
        result = (int(ce_seq_start[1]), int(ce_seq_end[0]))
    elif len(ce_seq_start) == 2 and len(ce_seq_end) == 2:  # start and end in gapped
        if ce_seq_start[0] == ce_seq_end[0] and ce_seq_start[1] == ce_seq_end[1]:  # region inside same gap
            result = ()  # if the region is inside a same gap then te region does not exist in the sequence
        else:
            result = (int(ce_seq_start[1]), int(ce_seq_end[0]))
    return result


def aligned_seq_to_cigar(aligned_seq: str) -> str:
    """Convert an aligned_seq to its cigar line

    The cigar line uses [length][operation] order and if the operation length is 1 it gives the operation only
    A-TGC---CC --> MD3M3D2M

    Args:
        aligned_seq: the aligned sequence

    Returns:
         cigar line
    """
    # to construct the cigar string each element of the line is added to the list and then join as a string.
    # this approach is more performant than using a successive concatenation of strings which runtime scale
    # quadratically with the length of the string in python
    list_cigar = []
    matches = 0
    gaps = 0
    for nt in aligned_seq:
        if nt == "-":
            if matches > 0:
                list_cigar.append("M" if matches == 1 else f"{matches}M")
                matches = 0
            gaps = gaps + 1
        else:
            if gaps > 0:
                list_cigar.append("D" if gaps == 1 else f"{gaps}D")
                gaps = 0
            matches = matches + 1
    ## process the remaining gap/matched after the loop
    if gaps == 1:
        list_cigar.append("D")
    elif gaps > 1:
        list_cigar.append(f"{gaps}D")
    elif matches == 1:
        list_cigar.append("M")
    elif matches > 1:
        list_cigar.append(f"{matches}M")

    return "".join(list_cigar)


def get_cigar_array(cigar: str) -> List[Tuple[int, str]]:
    """Return a list of the cigar line.

    Args:
        cigar: cigar line of the aligned sequence

    Returns:
        List of cigar [length][operation] tuples.

    Example:
        >>> x = get_cigar_array("34M12D5MD")
        >>> print(x)
        [(34, 'M'), (12, 'D'), (5, 'M'), (1, 'D')]
    """
    number = ""
    result = []
    for c in cigar:
        if c.isdigit():
            number = number + c
        else:
            op_length = int(number) if number else 1
            result.append((op_length, c))
            number = ""
    return result


def alignment_to_seq_coordinate(cigar: str, coord: int) -> List[int]:
    """Convert coordinate from the alignment level to sequence level

    This function will convert a position at the alignment level to the sequence level. To be able to
    deal with gaps and give the maximum information the function is return a list of position. If the
    position at the alignment level fall into a gap then the position just before the gap and just after
    the gap (in the same order) is returned in the list. If the position is on a non gapped part of the
    sequence then it returns the corresponding position at the sequence level in one list of a single element.

    Example:

        V                              V
    123456789       return      123456789     return
    ATGC---CG   --> [4,5]       ATGC---CG  --> [5]
    1234   56                   1234   56

    Args:
        cigar: cigar line of the aligned sequence
        coord: coordinate at the alignment level

    Returns:
        coordinate at the unaligned sequence level

    Raises:
        ValueError: if coord is <= 0 or if coord > alignment length
    """

    if coord < 1:
        raise ValueError(f"coord need to be > 0 : current value {coord}")

    result = []
    cigar_array = get_cigar_array(cigar)
    seq_level_coord = coord
    cum_aln_len = 0
    for op_length, operation in cigar_array:
        cum_aln_len += op_length
        if operation == "M":
            if coord <= cum_aln_len:
                # in this case coord is included in the M cigar_elem
                # so seq_level_coord has been trimmed of all the gaps and now has the correct coordinate
                result = [seq_level_coord]
                break
        elif operation == "D":
            if coord <= cum_aln_len:
                # in this case coord is included in the D cigar_elem
                # so we need to trim only a few gaps from seq_level_coord to have the correct coordinate
                last_match_pos = cum_aln_len - op_length
                gap_to_remove = coord - last_match_pos
                seq_level_coord = seq_level_coord - gap_to_remove
                result = [seq_level_coord, seq_level_coord+1]
                break
            seq_level_coord = seq_level_coord - op_length
        else:
            raise ValueError("no valid cigar line")

    if coord > cum_aln_len:
        raise ValueError(f"{coord} is larger than the maximum size of the alignment {cum_aln_len}")

    return result
