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
"""Process Cactus MAF file according to specified parameters."""

import argparse
import json
import os
import shutil
from tempfile import TemporaryDirectory

from Bio.Align import MultipleSeqAlignment
from Bio.AlignIO.MafIO import MafIterator, MafWriter
from Bio.Seq import Seq
import numpy as np


def trimming_maf_iterator(stream):
    """Yields a MAF block with gap-only columns trimmed out."""
    for aln_block in MafIterator(stream):
        gap_column = np.vstack(np.repeat(b"-", len(aln_block)))
        block_arr = np.array(aln_block, dtype=bytes)
        gap_col_mask = (block_arr == gap_column).all(axis=0)
        if gap_col_mask.any():
            for row_arr, aln_row in zip(block_arr[:, ~gap_col_mask], aln_block):
                aln_row.seq = Seq(row_arr.tobytes().decode("ascii"))
        yield aln_block


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_maf", help="Input MAF file.")
    parser.add_argument("processed_maf", help="Output processed MAF file.")

    parser.add_argument(
        "--min-block-rows",
        metavar="INT",
        type=int,
        default=2,
        help="Minimum number of alignment rows per block.",
    )
    parser.add_argument(
        "--min-block-cols",
        metavar="INT",
        type=int,
        default=20,
        help="Minimum number of alignment columns per block.",
    )
    parser.add_argument(
        "--min-seq-length",
        metavar="INT",
        type=int,
        default=5,
        help="Minimum unaligned sequence length of each aligned sequence.",
    )
    parser.add_argument(
        "--expected-block-count",
        metavar="INT",
        type=int,
        help="Expected number of alignment blocks in input MAF file.",
    )
    parser.add_argument(
        "--dataflow-file",
        help="Optional dataflow JSON file.",
    )
    args = parser.parse_args()

    stats_col_names = [
        "block_count_before_processing",
        "block_count_after_processing",
        "seq_count_after_processing",
    ]

    stats = dict.fromkeys(stats_col_names, 0)

    with TemporaryDirectory() as tmp_dir:
        temp_maf = os.path.join(tmp_dir, "temp.maf")
        with (
            open(args.input_maf, encoding="utf-8") as in_file_obj,
            open(temp_maf, "w", encoding="utf-8") as out_file_obj,
        ):
            writer = MafWriter(out_file_obj)
            writer.write_header()

            # The trimming_maf_iterator is not the most elegant or speedy solution, but
            # we need to remove gap-only columns before we apply any other filters.
            for maf_block in trimming_maf_iterator(in_file_obj):
                stats["block_count_before_processing"] += 1

                if maf_block.get_alignment_length() < args.min_block_cols:
                    continue

                processed_block = MultipleSeqAlignment([])
                for rec in maf_block:
                    if rec.annotations["size"] < args.min_seq_length:
                        continue
                    processed_block.append(rec)

                if len(processed_block) < args.min_block_rows:
                    continue

                writer.write_alignment(processed_block)
                stats["seq_count_after_processing"] += len(processed_block)
                stats["block_count_after_processing"] += 1

        if args.expected_block_count:
            if stats["block_count_before_processing"] != args.expected_block_count:
                raise RuntimeError(
                    f"Number of input blocks ({stats['block_count_before_processing']}) does"
                    f" not match expected block count ({args.expected_block_count})"
                )

        shutil.move(temp_maf, args.processed_maf)

    if args.dataflow_file:
        dataflow_branch = 2
        dataflow_json = json.dumps(
            {
                "maf_file": args.processed_maf,
                "maf_block_count": stats["block_count_after_processing"],
                "maf_seq_count": stats["seq_count_after_processing"],
            }
        )
        dataflow_event = f"{dataflow_branch} {dataflow_json}"

        with open(args.dataflow_file, "w", encoding="utf-8") as out_file_obj:
            print(dataflow_event, file=out_file_obj)
