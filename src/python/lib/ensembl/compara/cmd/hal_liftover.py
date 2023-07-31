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
"""HAL liftover console script module."""

from __future__ import annotations
import csv
import itertools
import json
import pathlib
from tempfile import TemporaryDirectory
from typing import Any, Dict, Iterable, Optional, TextIO, Union

import click
from cmmodule.mapregion import crossmap_region_file
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
    dst_2bit_file: Union[pathlib.Path, str],
    map_tree: Dict,
    flank_length: int = 0,
    src_name: Optional[str] = None,
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
        src_name: Optional name of source region.

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

    if src_region.name:
        rec["params"]["src_name"] = src_region.name

    rec["results"] = []
    with TemporaryDirectory() as tmp_dir:
        tmp_dir_path = pathlib.Path(tmp_dir)

        src_bed_file = tmp_dir_path / "src_regions.bed"
        make_src_region_file(
            src_region.chrom,
            src_region.start + 1,
            src_region.end,
            _strand_sign_to_num[src_region.strand],
            src_chr_sizes,
            src_bed_file,
            flank_length=flank_length,
        )

        dst_bed_file = tmp_dir_path / "dst_regions.bed"
        crossmap_region_file(map_tree, str(src_bed_file), str(dst_bed_file))
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


@click.command("hal-liftover", context_settings={"show_default": True})
@click.argument("hal_file", type=click.Path(exists=True, path_type=pathlib.Path))
@click.argument("src_genome")
@click.argument("dest_genome")
@click.argument("output_file", type=click.File("wt"))
@click.option("--src-region", metavar="STR", help="Region to liftover.")
@click.option(
    "--src-region-tsv",
    metavar="FILE",
    type=click.File("rt"),
    help="Input TSV file containing regions to liftover.",
)
@click.option(
    "--hal-cache",
    metavar="PATH",
    type=click.Path(path_type=pathlib.Path),
    help="Directory in which HAL-derived data files are created (e.g. genome sequence"
    " files). By default, the path of this directory is determined from the input"
    " HAL file (e.g. '/path/to/aln.hal'), by replacing the HAL file extension with"
    " the suffix '_cache' (e.g. '/path/to/aln_cache').",
)
@click.option(
    "--flank",
    metavar="INT",
    default=0,
    help="Requested length of upstream/downstream flanking regions to include in query.",
)
@click.option(
    "--linear-gap",
    metavar="STR|FILE",
    default="medium",
    help="Linear gap parameter passed unmodified to axtChain.",
)
@click.option(
    "--output-format",
    default="JSON",
    metavar="STR",
    type=click.Choice(["JSON", "TSV"], case_sensitive=False),
    help="Format of output file.",
)
def main(
    hal_file: pathlib.Path,
    src_genome: str,
    dest_genome: str,
    output_file: TextIO,
    src_region: str,
    src_region_tsv: click.File,
    hal_cache: pathlib.Path,
    flank: int,
    linear_gap: str,
    output_format: str,
) -> None:
    """Do a liftover between two genome sequences in a HAL file."""

    if hal_cache is None:
        hal_cache = pathlib.Path(f"{hal_file.stem}_cache")

    destination_2bit_file = hal_cache / "genome" / "2bit" / f"{dest_genome}.2bit"
    if not destination_2bit_file.is_file():
        raise RuntimeError(f"cannot find destination genome 2bit file {destination_2bit_file}")

    cached_chain_dir = hal_cache / "sequence" / "chain"

    chrom_sizes_file_path = hal_cache / "genome" / "chrom_sizes" / f"{src_genome}.chrom.sizes"
    source_chr_sizes = load_chrom_sizes_file(chrom_sizes_file_path)

    if src_region is not None:
        if src_region_tsv is not None:
            raise RuntimeError("only one of '--src-region' or '--src-region-tsv' can be set")
        source_regions = [SimpleRegion.from_1_based_region_string(src_region)]
    elif src_region_tsv is not None:
        reader = csv.DictReader(src_region_tsv, dialect=UnquotedUnixTab)
        region_to_name = {}
        source_regions = []
        for row in reader:
            source_region_name = row["name"] if "name" in row and row["name"] else None
            source_region = SimpleRegion.from_1_based_region_attribs(
                row["chr"], row["start"], row["end"], row["strand"], name=source_region_name
            )
            source_regions.append(source_region)
    else:
        raise RuntimeError("one of '--src-region' or '--src-region-tsv' must be set")

    regions_by_chr = {k: list(x) for k, x in itertools.groupby(source_regions, key=lambda x: x.chrom)}
    source_chr_names = sorted(regions_by_chr)

    records = []
    for source_chr_name in source_chr_names:
        cached_chain_name = f"{src_genome}_{source_chr_name}_to_{dest_genome}.linearGap_{linear_gap}.chain.gz"
        cached_chain_path = cached_chain_dir / cached_chain_name

        crossmap_tree, *_unused = read_chain_file(str(cached_chain_path))

        for source_region in regions_by_chr[source_chr_name]:
            record = liftover_via_chain(
                source_region,
                src_genome,
                source_chr_sizes,
                dest_genome,
                destination_2bit_file,
                crossmap_tree,
                flank_length=flank,
            )
            records.append(record)

    write_liftover_output(records, output_format, output_file)


def write_liftover_output(records: Iterable[Dict[str, Any]], output_format: str, output_file: TextIO) -> None:
    """Write liftover output.

    Args:
        records: Records to output.
        output_format: Output format.
        output_file: Output file stream.
    """
    if output_format == "JSON":
        json.dump(records, output_file)

    elif output_format == "TSV":
        output_field_names = [
            "src_genome",
            "src_name",
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

        writer = csv.DictWriter(output_file, output_field_names, dialect=UnquotedUnixTab)
        writer.writeheader()
        for record in records:
            params = record["params"]
            for result in record["results"]:
                writer.writerow({**params, **result})
    else:
        raise ValueError(f"unsupported output format: {output_format}")
