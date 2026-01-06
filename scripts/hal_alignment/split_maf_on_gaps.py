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
"""Split a MAF file on gaps in non-reference sequence.

Given an input MAF file in which each block has two aligned sequences (an
ungapped reference sequence and a possibly gapped non-reference sequence),
this script splits each MAF block into one or more gapless MAF blocks.
"""

import argparse
import json
import os
import re
import shutil
from tempfile import TemporaryDirectory

from Bio.Align import MultipleSeqAlignment
from Bio.AlignIO.MafIO import MafIterator, MafWriter
from Bio.SeqRecord import SeqRecord


def main() -> None:
    """Main function of script."""

    maf_keys = ["start", "strand", "srcSize"]  # these MAF fields are stored in SeqRecord annotations
    ungapped_re = re.compile("[^-]+")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_maf", help="Input MAF file.")
    parser.add_argument("output_maf", help="Output MAF file with ungapped alignment blocks.")
    parser.add_argument("--dataflow-file", help="Optional dataflow JSON file.")
    args = parser.parse_args()

    stats_col_names = [
        "block_count_after_processing",
        "seq_count_after_processing",
    ]

    stats = dict.fromkeys(stats_col_names, 0)

    with TemporaryDirectory() as tmp_dir:
        temp_maf = os.path.join(tmp_dir, "temp.maf")

        with (
            open(args.input_maf, encoding="utf-8") as in_file_obj,
            open(temp_maf, mode="w", encoding="utf-8") as out_file_obj,
        ):
            writer = MafWriter(out_file_obj)
            writer.write_header()
            for maf_block in MafIterator(in_file_obj):
                try:
                    ref_rec, alt_rec = maf_block
                except ValueError as exc:
                    raise ValueError(
                        f"cannot process MAF alignment; MAF block has {len(maf_block)} sequences"
                    ) from exc
                if "-" in ref_rec.seq:
                    raise ValueError("cannot process MAF alignment; reference sequence contains gaps")

                ref_start, ref_strand, ref_src_size = (ref_rec.annotations[k] for k in maf_keys)
                alt_start, alt_strand, alt_src_size = (alt_rec.annotations[k] for k in maf_keys)

                cumul_chunk_length = 0
                for match in ungapped_re.finditer(str(alt_rec.seq)):
                    chunk_start, chunk_stop = match.span()
                    chunk_length = chunk_stop - chunk_start

                    chunk_ref_seq = ref_rec.seq[chunk_start:chunk_stop]
                    chunk_ref_annot = {
                        "start": ref_start + chunk_start,
                        "size": chunk_length,
                        "strand": ref_strand,
                        "srcSize": ref_src_size,
                    }
                    chunk_ref_rec = SeqRecord(
                        seq=chunk_ref_seq,
                        id=ref_rec.id,
                        name=ref_rec.name,
                        description=ref_rec.description,
                        annotations=chunk_ref_annot,
                    )

                    chunk_alt_seq = alt_rec.seq[chunk_start:chunk_stop]
                    chunk_alt_annot = {
                        "start": alt_start + cumul_chunk_length,
                        "size": chunk_length,
                        "strand": alt_strand,
                        "srcSize": alt_src_size,
                    }
                    chunk_alt_rec = SeqRecord(
                        seq=chunk_alt_seq,
                        id=alt_rec.id,
                        name=alt_rec.name,
                        description=alt_rec.description,
                        annotations=chunk_alt_annot,
                    )

                    chunk = MultipleSeqAlignment([chunk_ref_rec, chunk_alt_rec])
                    writer.write_alignment(chunk)
                    cumul_chunk_length += chunk_length

                    stats["seq_count_after_processing"] += len(chunk)
                    stats["block_count_after_processing"] += 1

        shutil.move(temp_maf, args.output_maf)

    if args.dataflow_file:
        dataflow_branch = 2
        dataflow_json = json.dumps(
            {
                "maf_file": args.output_maf,
                "maf_block_count": stats["block_count_after_processing"],
                "maf_seq_count": stats["seq_count_after_processing"],
            }
        )
        dataflow_event = f"{dataflow_branch} {dataflow_json}"

        with open(args.dataflow_file, mode="w", encoding="utf-8") as out_file_obj:
            print(dataflow_event, file=out_file_obj)


if __name__ == "__main__":
    main()
