#!/usr/bin/env python3
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
"""Make a liftover source BED file."""

from __future__ import annotations
from argparse import ArgumentParser
from pathlib import Path

from ensembl.compara.utils.hal import make_src_region_file, SimpleRegion
from ensembl.compara.utils.ucsc import load_chrom_sizes_file


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("hal_file", help="Input HAL file.")
    parser.add_argument("chrom_sizes_dir", help="Directory of chrom sizes files.")
    parser.add_argument("source_genome", help="Source HAL genome name.")
    parser.add_argument("source_sequence", help="Source HAL sequence name.")
    parser.add_argument("bed_file", help="Source region BED file.")
    parser.add_argument(
        "--start",
        metavar="INT",
        type=int,
        help="Start position of source location (0-based).",
    )
    parser.add_argument(
        "--end",
        metavar="INT",
        type=int,
        help="End position of source location (0-based).",
    )
    parser.add_argument("--strand", choices=["+", "-"], help="Strand of source location.")
    args = parser.parse_args()

    chrom_sizes_dir_path = Path(args.chrom_sizes_dir)
    chrom_sizes_file_path = chrom_sizes_dir_path / f"{args.source_genome}.chrom.sizes"
    source_chr_sizes = load_chrom_sizes_file(chrom_sizes_file_path)

    region_start = args.start if args.start is not None else 0
    region_end = args.end if args.end else source_chr_sizes[args.source_sequence]
    region_strand = args.strand if args.strand else "+"

    source_regions = [SimpleRegion(args.source_sequence, region_start, region_end, region_strand)]
    make_src_region_file(source_regions, args.source_genome, source_chr_sizes, args.bed_file)
