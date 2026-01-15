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
"""Map MAF src field values."""

import argparse
import csv
import os
import shutil
from tempfile import TemporaryDirectory

from Bio.AlignIO.MafIO import MafIterator, MafWriter


def main() -> None:
    """Main function of script."""

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_maf", help="Input MAF file.")
    parser.add_argument("output_maf", help="Output MAF file with src fields updated.")
    parser.add_argument("--src-map-file", action="append", help="Input MAF src field mapping TSV file.")
    parser.add_argument(
        "--only-seq-name",
        action="store_true",
        help="Output sequence name without its corresponding assembly UUID.",
    )

    args = parser.parse_args()

    src_map = {}
    for src_map_file in args.src_map_file:
        with open(src_map_file, encoding="utf-8") as in_file_obj:
            reader = csv.DictReader(in_file_obj, delimiter="\t")
            for row in reader:
                old_src = f"{row['hal_genome_name']}.{row['hal_sequence_name']}"
                new_src = row["assembly_sequence"]
                if old_src in src_map:
                    raise ValueError(f"duplicate old src field: {old_src}")
                src_map[old_src] = new_src

    with TemporaryDirectory() as tmp_dir:
        temp_maf = os.path.join(tmp_dir, "temp.maf")

        with (
            open(args.input_maf, encoding="utf-8") as in_file_obj,
            open(temp_maf, mode="w", encoding="utf-8") as out_file_obj,
        ):
            writer = MafWriter(out_file_obj)
            writer.write_header()
            for maf_block in MafIterator(in_file_obj):
                num_mapped = 0
                for rec in maf_block:
                    if rec.id in src_map:
                        rec.id = rec.name = src_map[rec.id]
                        num_mapped += 1

                if num_mapped == len(maf_block):
                    writer.write_alignment(maf_block)

        shutil.move(temp_maf, args.output_maf)


if __name__ == "__main__":
    main()
