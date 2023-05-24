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
from dataclasses import dataclass, InitVar
from pathlib import Path
import re
import subprocess
from typing import Dict, Iterable, Mapping, Union


@dataclass(frozen=True)
class SimpleRegion:
    """A simple DNA sequence region."""
    chr: str
    start: int
    end: int
    strand: str
    validate: InitVar[bool] = True

    def __post_init__(self, validate):
        if validate:
            if self.start < 0:
                raise ValueError(
                    f"0-based region start must be greater than or equal to 0: {self.start}"
                )

            if self.start >= self.end:
                raise ValueError(
                    f"0-based region end ({self.end}) must be greater than region start ({self.start})"
                )

            if self.strand not in ("+", "-"):
                raise ValueError(f"0-based region has invalid strand: '{self.strand}'")

    @classmethod
    def from_1_based_region_string(cls, region_string: str) -> SimpleRegion:
        """Create a region object from a 1-based region string.

        Args:
            region_string: A 1-based region string.

        Returns:
            A region object.

        Raises:
            ValueError: If `region_string` is an invalid 1-based region string.
        """

        seq_region_regex = re.compile(
            r"^(?P<chr>[^:]+):(?P<start>[0-9]+)-(?P<end>[0-9]+):(?P<strand>.+)$"
        )
        match = seq_region_regex.match(region_string)

        if match := seq_region_regex.fullmatch(region_string):
            region = cls.from_1_based_region_attribs(
                match["chr"], match["start"], match["end"], match["strand"]
            )
        else:
            raise ValueError(
                f"failed to tokenise 1-based region string: '{region_string}'"
            )

        return region

    @classmethod
    def from_1_based_region_attribs(
        cls,
        chr_: str,
        start: Union[int, str],
        end: Union[int, str],
        strand: Union[int, str],
    ) -> SimpleRegion:
        """Create a region object from 1-based region attributes.

        Args:
            chr_: Region chromosome name.
            start: Region start position.
            end: Region end position.
            strand: Region strand; either '1' for plus strand or '-1' for minus strand.

        Returns:
            A region object.

        Raises:
            ValueError: If the region attributes represent an invalid region.
        """
        _strand_num_to_sign = {1: "+", -1: "-"}

        start = int(start)
        end = int(end)

        if start < 1:
            raise ValueError(
                f"1-based region start must be greater than or equal to 1: {start}"
            )

        if start > end:
            raise ValueError(
                f"1-based region end ({end}) must be greater than or equal to region start ({start})"
            )

        try:
            strand = _strand_num_to_sign[int(strand)]
        except (KeyError, ValueError) as exc:
            raise ValueError(f"1-based region has invalid strand: '{strand}'") from exc

        return cls(chr_, start - 1, end, strand, validate=False)

    def to_1_based_region_string(self):
        """Get the 1-based region string corresponding to this region."""
        strand_num = 1 if self.strand == "+" else -1
        return f"{self.chr}:{self.start + 1}-{self.end}:{strand_num}"


def load_chr_sizes(hal_file: Union[Path, str], genome_name: str) -> Dict[str, int]:
    """Load chromosome sizes from an input HAL file.

    Args:
        hal_file: Input HAL file.
        genome_name: Name of the genome to get the chromosome sizes of.

    Returns:
        Dictionary mapping chromosome names to their lengths.
    """
    cmd = ["halStats", "--chromSizes", genome_name, hal_file]
    process = subprocess.run(
        cmd, check=True, capture_output=True, text=True, encoding="ascii"
    )

    chr_sizes = {}
    for line in process.stdout.splitlines():
        chr_name, chr_size = line.rstrip().split("\t")
        chr_sizes[chr_name] = int(chr_size)

    return chr_sizes


def make_src_region_file(
    regions: Iterable[SimpleRegion],
    genome: str,
    chr_sizes: Mapping[str, int],
    bed_file: Union[Path, str],
    flank_length: int = 0,
) -> None:
    """Make source region file.

    Args:
        regions: Regions to write to output file.
        genome: Genome for which the regions are specified.
        chr_sizes: Mapping of chromosome names to their lengths.
        bed_file: Path of BED file to output.
        flank_length: Length of upstream/downstream flanking regions to request.

    Raises:
        ValueError: If any region has an unknown chromosome or invalid coordinates,
            or if ``flank_length`` is negative.
    """
    if flank_length < 0:
        raise ValueError(
            f"'flank_length' must be greater than or equal to 0: {flank_length}"
        )

    with open(bed_file, "w") as f:
        name = "."
        score = 0  # halLiftover requires an integer score in BED input
        for region in regions:
            try:
                chr_size = chr_sizes[region.chr]
            except KeyError as exc:
                raise ValueError(
                    f"chromosome ID '{region.chr}' not found in HAL genome '{genome}'"
                ) from exc

            if region.start < 0:
                raise ValueError(
                    f"region start must be greater than or equal to 0: {region.start}"
                )

            if region.end > chr_size:
                raise ValueError(
                    f"region end ({region.end}) must not be greater than the"
                    f" corresponding chromosome length ({region.chr}: {chr_size})"
                )

            flanked_start = max(0, region.start - flank_length)
            flanked_end = min(region.end + flank_length, chr_size)

            fields = [
                region.chr,
                flanked_start,
                flanked_end,
                name,
                score,
                region.strand,
            ]
            print("\t".join(str(x) for x in fields), file=f)


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("hal_file", help="Input HAL file.")
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
    parser.add_argument(
        "--strand", choices=["+", "-"], help="Strand of source location."
    )
    args = parser.parse_args()

    source_chr_sizes = load_chr_sizes(args.hal_file, args.source_genome)

    region_start = args.start if args.start is not None else 0
    region_end = args.end if args.end else source_chr_sizes[args.source_sequence]
    region_strand = args.strand if args.strand else "+"

    source_regions = [
        SimpleRegion(args.source_sequence, region_start, region_end, region_strand)
    ]
    make_src_region_file(
        source_regions, args.source_genome, source_chr_sizes, args.bed_file
    )
