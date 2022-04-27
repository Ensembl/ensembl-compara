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
"""Collection of utils methods targeted to cigar line manipulation.

Typical usage examples::


"""

__all__ = ['aligned_seq_to_cigar', 'alignment_to_seq_coordinate', 'get_cigar_array']

from typing import List

def aligned_seq_to_cigar(aligned_seq:str) -> str:
    """ Convert an aligned_seq to its cigar line

    Params:
        aligned_seq: the aligned sequence (str)

    Returns:
         cigar line (str)
    """
    cigar = ""
    matches = 0
    gaps = 0
    for nt in aligned_seq:
        if nt == "-" and matches == 0:
            gaps = gaps + 1
        elif nt == "-" and matches == 1:
            cigar = f"{cigar}M"
            matches = 0
            gaps = gaps + 1
        elif nt == "-" and matches > 1: # matches > 1
            cigar = f"{cigar}M{matches}"
            matches = 0
            gaps = gaps + 1
        elif nt != "-" and gaps == 0:
            matches = matches + 1
        elif nt != "-" and gaps == 1:
            cigar = f"{cigar}D"
            gaps = 0
            matches = matches + 1
        elif nt != "-" and gaps > 1:
            cigar = f"{cigar}D{gaps}"
            gaps = 0
            matches = matches + 1

    ## process the remaining gap/matched after the loop
    if gaps != 0 and gaps == 1:
        cigar = f"{cigar}D"
    elif gaps != 0 and gaps > 1:
        cigar = f"{cigar}D{gaps}"
    elif matches != 0 and matches == 1:
        cigar = f"{cigar}M"
    elif matches != 0 and matches > 1:
        cigar = f"{cigar}M{matches}"

    return cigar


def get_cigar_array(cigar:str) -> List:
    """Return an array of the cigar line, e.g.: [('M', 34), ('D', 12), ('M', 5) ...]

    Params:
        cigar: cigar line of the aligned sequence (str)

    Returns:
        cigar array (list<tuple>)
    """
    number = ""
    result = []
    symbol = ""
    for c in cigar:
        if not c.isdigit():
            if symbol == "" and number == "":
                symbol = c
            elif symbol != "" and number == "": # new symbol precede by a different symbol then leght is 1
                result.append((symbol, 1))
                symbol = c
            elif symbol != "" and number != "":
                result.append((symbol, int(number)))
                number = ""
                symbol = c
        else:  # in this case chr.isdigit():
            number = number + c
    if number != "":
        result.append((symbol, int(number)))
    return result


def alignment_to_seq_coordinate(cigar: str, coord: int) -> int:
    '''Covert coordinate from the alignment level to sequence level

    Params:
        cigar: cigar line of the aligned sequence (str)
        coord: coordinate at the alignment level (int)

    Returns:
        coordinate at the unaligned sequence level (int)

    Raises:
        ValueError :  if coord is  <= 0 and if coord > alignment length
    '''

    if coord < 1:
        raise ValueError(f"coord need to be > 0 : current value {coord}")

    cigar_array =  get_cigar_array(cigar)
    seq_level_coord = coord
    align_index = 0
    for cigar_elem in cigar_array:
        align_index = align_index + cigar_elem[1]
        if cigar_elem[0] == "M":
            if coord <= align_index:
                # in this case coord is included in the M cigar_elem
                # so seq_level_coord  has been trim from all the gap and has now the correct coordinate
                break
        elif cigar_elem[0] == "D":
            if coord <= align_index:
                # in this case coord is included in the D cigar_elem
                # so we need to trim only a few gaps from seq_level_coord  to have the correct coordinate
                start_gap = align_index - cigar_elem[1]
                gap_to_remove = coord - start_gap
                seq_level_coord = seq_level_coord - gap_to_remove
                break
            seq_level_coord = seq_level_coord - cigar_elem[1]
        else:
            raise ValueError("no valid cigar line")

    if coord > align_index:
        raise ValueError(f"{coord} is larger than the maximum size of the alignment {align_index}")

    return seq_level_coord
