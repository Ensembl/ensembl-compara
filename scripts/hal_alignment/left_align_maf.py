#!/usr/bin/env python3
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Left-align indels in non-reference sequence of a MAF file.

Given an input MAF file in which each block has two aligned sequences (an
ungapped reference sequence and a possibly gapped non-reference sequence),
this script left-aligns any indels in the non-reference sequence.
"""

import argparse
import os
import re
import shutil
from tempfile import TemporaryDirectory

from Bio.Align import MultipleSeqAlignment
from Bio.AlignIO.MafIO import MafIterator, MafWriter
from Bio.Seq import Seq


def left_align_indels(maf_block):
    """Left-align indels in a MAF block.

    Args:
        maf_block: An input MAF block with two sequences, in which the
            reference sequence is ungapped and on the positive strand.

    Returns:
        The input MAF block, with non-reference indels left-aligned.
    """

    gap_byte_re = re.compile(b"-{1,}")
    gap_byte_value = ord(b"-")

    try:
        ref_rec, alt_rec = maf_block
    except ValueError as exc:
        if re.match(r"(not enough values to unpack|too many values to unpack)", str(exc)):
            raise ValueError(
                f"cannot process MAF alignment; MAF block has {len(maf_block)} sequences"
            ) from exc
        raise

    if ref_rec.annotations["strand"] != 1:
        # This function assumes the MAF reference is on the positive strand.
        raise ValueError("cannot process MAF alignment; MAF reference sequence is not on the positive strand")

    ref_seq_str = str(ref_rec.seq)
    alt_seq_str = str(alt_rec.seq)
    if "-" in ref_seq_str:
        # This function assumes the MAF reference is ungapped.
        raise ValueError("cannot process MAF alignment; MAF reference sequence contains gaps")

    if "-" in alt_seq_str:
        ref_seq_bytes = bytearray(ref_seq_str, encoding="ascii")
        alt_seq_bytes = bytearray(alt_seq_str, encoding="ascii")

        gap_spans = []
        for match in gap_byte_re.finditer(alt_seq_bytes):
            gap_spans.append(match.span())

        for gap_start, gap_stop in gap_spans:
            # We use byte ranges in the test clause to enable
            # us to check for case-insensitive equality.
            while (
                ref_seq_bytes[gap_stop - 1 : gap_stop].upper()  # ref base aligning with final gap site
                == alt_seq_bytes[gap_start - 1 : gap_start].upper()  # alt base just before initial gap site
            ):
                # Once we've checked for case-insensitive equality,
                # we can deal with bytes as integer values.
                alt_seq_bytes[gap_stop - 1] = alt_seq_bytes[gap_start - 1]
                alt_seq_bytes[gap_start - 1] = gap_byte_value
                gap_start -= 1
                gap_stop -= 1

        new_alt_seq_str = Seq(alt_seq_bytes.decode(encoding="ascii"))
        if new_alt_seq_str != alt_seq_str:
            alt_rec.seq = Seq(new_alt_seq_str)
            maf_block = MultipleSeqAlignment([ref_rec, alt_rec])

    return maf_block


def main() -> None:
    """Main function of script."""

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_maf", help="Input MAF file.")
    parser.add_argument("output_maf", help="Output MAF file with any indels left-aligned.")
    args = parser.parse_args()

    with TemporaryDirectory() as tmp_dir:
        temp_maf = os.path.join(tmp_dir, "temp.maf")

        with (
            open(args.input_maf, encoding="utf-8") as in_file_obj,
            open(temp_maf, mode="w", encoding="utf-8") as out_file_obj,
        ):
            writer = MafWriter(out_file_obj)
            writer.write_header()
            for maf_block in MafIterator(in_file_obj):
                maf_block = left_align_indels(maf_block)
                writer.write_alignment(maf_block)

        shutil.move(temp_maf, args.output_maf)


if __name__ == "__main__":
    main()
