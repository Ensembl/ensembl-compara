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

"""Do a liftover between two genome sequences in a HAL file.

Examples::
    # Do a liftover from GRCh38 to CHM13 of the human INS gene
    # along with 5 kb upstream and downstream flanking regions.
    python hal_gene_liftover.py --src-region 'chr11:2159779-2161221:-1' \
        --flank 5000 input.hal GRCh38 CHM13 output.json

    # Do a liftover from GRCh38 to CHM13 of
    # regions specified in an input TSV file.
    python hal_gene_liftover.py --src-region-tsv input.tsv \
        --flank 5000 input.hal GRCh38 CHM13 output.json

"""

from __future__ import annotations
from argparse import ArgumentParser
import csv
import itertools
import json
import os
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any, Dict, Union

from cmmodule.mapbed import crossmap_bed_file
from cmmodule.utils import read_chain_file

from ensembl.compara.utils.csv import UnquotedUnixTab
from ensembl.compara.utils.hal import (
    extract_region_sequences_from_2bit,
    extract_regions_from_bed,
    make_src_region_file,
    SimpleRegion,
)
from ensembl.compara.utils.ucsc import load_chrom_sizes_file


def liftover_via_chain(
    src_region: SimpleRegion,
    src_genome: str,
    src_chr_sizes: Dict[str, int],
    dst_genome: str,
    dst_2bit_file: Union[Path, str],
    map_tree: Dict,
    flank_length: int = 0,
) -> Dict[str, Any]:
    """Liftover a region using a pairwise assembly chain file.

    Args:
        src_region: Region to liftover.
        src_genome: Source genome.
        src_chr_sizes: Source genome chromosome name-to-length mapping.
        dst_genome: Destination genome.
        dst_2bit_file: 2bit file of destination genome sequences.
        map_tree: Dictionary mapping chromosome name to interval tree.
        flank_length: Length of upstream/downstream flanking regions to request.

    Returns:
        Dictionary containing liftover parameters and results.

    """
    _strand_sign_to_num = {"+": 1, "-": -1}

    rec: Dict[str, Any] = {}
    rec["params"] = {
        "src_genome": src_genome,
        "src_chr": src_region.chrom,
        "src_start": src_region.start + 1,
        "src_end": src_region.end,
        "src_strand": _strand_sign_to_num[src_region.strand],
        "flank": flank_length,
        "dest_genome": dst_genome,
    }

    rec["results"] = []
    with TemporaryDirectory() as tmp_dir:
        src_bed_file = os.path.join(tmp_dir, "src_regions.bed")
        make_src_region_file(
            [src_region],
            src_genome,
            src_chr_sizes,
            src_bed_file,
            flank_length=flank_length,
        )

        dst_bed_file = os.path.join(tmp_dir, "dst_regions.bed")
        crossmap_bed_file(map_tree, src_bed_file, dst_bed_file)
        dst_regions = extract_regions_from_bed(dst_bed_file)

        if not dst_regions:
            return rec

        dst_sequences = extract_region_sequences_from_2bit(dst_regions, dst_2bit_file)

        for dst_region, dst_sequence in zip(dst_regions, dst_sequences):
            rec["results"].append(
                {
                    "dest_chr": dst_region.chrom,
                    "dest_start": dst_region.start + 1,
                    "dest_end": dst_region.end,
                    "dest_strand": _strand_sign_to_num[dst_region.strand],
                    "dest_sequence": dst_sequence,
                }
            )

    return rec


if __name__ == "__main__":
    parser = ArgumentParser(description="Performs a gene liftover between two haplotypes in a HAL file.")
    parser.add_argument("hal_file", help="Input HAL file.")
    parser.add_argument("src_genome", help="Source genome name.")
    parser.add_argument("dest_genome", help="Destination genome name.")
    parser.add_argument("output_file", help="Output file.")

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--src-region", metavar="STR", help="Region to liftover.")
    group.add_argument(
        "--src-region-tsv",
        metavar="FILE",
        help="Input TSV file containing regions to liftover.",
    )

    parser.add_argument(
        "--flank",
        metavar="INT",
        default=0,
        type=int,
        help="Requested length of upstream/downstream" " flanking regions to include in query.",
    )
    parser.add_argument(
        "--linear-gap",
        metavar="STR|FILE",
        default="medium",
        help="axtChain linear gap parameter.",
    )

    parser.add_argument(
        "--output-format",
        metavar="STR",
        default="JSON",
        choices=["JSON", "TSV"],
        help="Format of output file.",
    )

    parser.add_argument(
        "--hal-cache",
        metavar="PATH",
        help="Directory in which HAL-derived data files are created (e.g. genome sequence"
        " files). By default, the path of this directory is determined from the input"
        " HAL file (e.g. '/path/to/aln.hal'), by replacing the HAL file extension with"
        " the suffix '_cache' (e.g. '/path/to/aln_cache').",
    )
    args = parser.parse_args()

    if args.hal_cache is not None:
        hal_cache = args.hal_cache
    else:
        hal_file_stem, _ = os.path.splitext(args.hal_file)
        hal_cache = f"{hal_file_stem}_cache"
    os.makedirs(hal_cache, exist_ok=True)

    source_2bit_file = os.path.join(hal_cache, "genome", "2bit", f"{args.src_genome}.2bit")
    if not os.path.isfile(source_2bit_file):
        raise RuntimeError(f"cannot find source genome 2bit file {source_2bit_file}")

    destination_2bit_file = os.path.join(hal_cache, "genome", "2bit", f"{args.dest_genome}.2bit")
    if not os.path.isfile(destination_2bit_file):
        raise RuntimeError(f"cannot find destination genome 2bit file {destination_2bit_file}")

    cached_chain_dir = os.path.join(hal_cache, "sequence", "chain")

    chrom_sizes_file_path = os.path.join(
        args.hal_cache, "genome", "chrom_sizes", f"{args.src_genome}.chrom.sizes"
    )
    source_chr_sizes = load_chrom_sizes_file(chrom_sizes_file_path)

    if args.src_region is not None:
        source_regions = [SimpleRegion.from_1_based_region_string(args.src_region)]
    else:
        with open(args.src_region_tsv) as tsv_file_obj:
            reader = csv.DictReader(tsv_file_obj, dialect=UnquotedUnixTab)
            source_regions = [
                SimpleRegion.from_1_based_region_attribs(row["chr"], row["start"], row["end"], row["strand"])
                for row in reader
            ]

    regions_by_chr = {k: list(x) for k, x in itertools.groupby(source_regions, key=lambda x: x.chrom)}
    source_chr_names = sorted(regions_by_chr)

    records = []
    for source_chr_name, source_regions in regions_by_chr.items():
        cached_chain_name = (
            f"{args.src_genome}_{source_chr_name}_to_{args.dest_genome}.linearGap_{args.linear_gap}.chain.gz"
        )
        cached_chain_path = os.path.join(cached_chain_dir, cached_chain_name)

        crossmap_tree, *_unused = read_chain_file(cached_chain_path)
        for source_region in source_regions:
            record = liftover_via_chain(
                source_region,
                args.src_genome,
                source_chr_sizes,
                args.dest_genome,
                destination_2bit_file,
                crossmap_tree,
                flank_length=args.flank,
            )
            records.append(record)

    if args.output_format == "JSON":
        with open(args.output_file, "w") as file_obj:
            json.dump(records, file_obj)

    elif args.output_format == "TSV":
        output_field_names = [
            "src_genome",
            "src_chr",
            "src_start",
            "src_end",
            "src_strand",
            "flank",
            "dest_genome",
            "lifted_src_chr",
            "lifted_src_start",
            "lifted_src_end",
            "lifted_src_strand",
            "dest_chr",
            "dest_start",
            "dest_end",
            "dest_strand",
            "dest_sequence",
        ]

        with open(args.output_file, "w") as file_obj:
            writer = csv.DictWriter(file_obj, output_field_names, dialect=UnquotedUnixTab)
            writer.writeheader()
            for record in records:
                params = record["params"]
                for result in record["results"]:
                    writer.writerow({**params, **result})
