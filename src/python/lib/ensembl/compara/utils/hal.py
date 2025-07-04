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
"""Utilities for working with HAL data."""

from __future__ import annotations

__all__ = [
    "extract_region_sequences_from_2bit",
    "extract_regions_from_bed",
    "make_src_region_file",
    "SimpleRegion",
]

from dataclasses import dataclass, InitVar
import os
from pathlib import Path
import re
import subprocess
from tempfile import TemporaryDirectory
from typing import Iterable, List, Mapping, Optional, Union

from Bio.SeqIO.FastaIO import SimpleFastaParser


@dataclass(frozen=True)
class SimpleRegion:
    """A simple DNA sequence region."""

    chrom: str
    start: int
    end: int
    strand: str
    validate: InitVar[bool] = True
    name: Optional[str] = None

    def __post_init__(self, validate):
        if validate:
            if self.start < 0:
                raise ValueError(f"0-based region start must be greater than or equal to 0: {self.start}")

            if self.start >= self.end:
                raise ValueError(
                    f"0-based region end ({self.end}) must be greater than region start ({self.start})"
                )

            if self.strand not in ("+", "-"):
                raise ValueError(f"0-based region has invalid strand: '{self.strand}'")

    @classmethod
    def from_1_based_region_string(cls, region_string: str, name: Optional[str] = None) -> SimpleRegion:
        """Create a region object from a 1-based region string.

        Args:
            region_string: A 1-based region string.

        Returns:
            A region object.

        Raises:
            ValueError: If ``region_string`` is an invalid 1-based region string.
        """

        seq_region_regex = re.compile(r"^(?P<chrom>[^:]+):(?P<start>[0-9]+)-(?P<end>[0-9]+):(?P<strand>.+)$")
        match = seq_region_regex.match(region_string)

        if match := seq_region_regex.fullmatch(region_string):
            region = cls.from_1_based_region_attribs(
                match["chrom"],
                match["start"],
                match["end"],
                match["strand"],
                name=name,
            )
        else:
            raise ValueError(f"failed to tokenise 1-based region string: '{region_string}'")

        return region

    @classmethod
    def from_1_based_region_attribs(
        cls,
        chrom: str,
        start: Union[int, str],
        end: Union[int, str],
        strand: Union[int, str],
        name: Optional[str] = None,
    ) -> SimpleRegion:
        """Create a region object from 1-based region attributes.

        Args:
            chrom: Genome sequence name.
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
            raise ValueError(f"1-based region start must be greater than or equal to 1: {start}")

        if start > end:
            raise ValueError(
                f"1-based region end ({end}) must be greater than or equal to region start ({start})"
            )

        try:
            strand = _strand_num_to_sign[int(strand)]
        except (KeyError, ValueError) as exc:
            raise ValueError(f"1-based region has invalid strand: '{strand}'") from exc

        return cls(chrom, start - 1, end, strand, name=name, validate=False)

    def to_1_based_region_string(self):
        """Get the 1-based region string corresponding to this region."""
        strand_num = 1 if self.strand == "+" else -1
        return f"{self.chrom}:{self.start + 1}-{self.end}:{strand_num}"


def extract_region_sequences_from_2bit(
    regions: Iterable[SimpleRegion], two_bit_file: Union[Path, str]
) -> List[str]:
    """Extract region sequences from a 2bit file.

    Args:
        regions: Regions to extract.
        two_bit_file: 2bit sequence file.

    Returns:
        List of region sequences.
    """
    with TemporaryDirectory() as tmp_dir:
        tmp_bed_file = os.path.join(tmp_dir, "regions.bed")
        with open(tmp_bed_file, "w") as out_file_obj:
            for idx, region in enumerate(regions):
                fields = [region.chrom, region.start, region.end, idx, 0, region.strand]
                print("\t".join(str(x) for x in fields), file=out_file_obj)

        tmp_fasta_file = os.path.join(tmp_dir, "regions.fa")
        cmd_args = ["twoBitToFa", f"-bed={tmp_bed_file}", two_bit_file, tmp_fasta_file]
        subprocess.run(cmd_args, check=True)

        with open(tmp_fasta_file) as in_file_obj:
            sequences = [seq for _, seq in SimpleFastaParser(in_file_obj)]

    return sequences


def extract_regions_from_bed(bed_file: Union[Path, str]) -> List[SimpleRegion]:
    """Extract liftover destination regions from a BED file.

    Args:
        bed_file: Input BED file.

    Returns:
        List of regions.
    """
    dst_regions = []
    with open(bed_file) as in_file_obj:
        for line in in_file_obj:
            chrom, start, end, _name, _score, strand, *_unused = line.rstrip("\n").split("\t")
            dst_regions.append(SimpleRegion(chrom, int(start), int(end), strand))

    return dst_regions


def make_src_region_file(
    chrom: str,
    start: int,
    end: int,
    strand: int,
    chrom_sizes: Mapping[str, int],
    bed_file: Union[Path, str],
    flank_length: int = 0,
) -> None:
    """Make source region BED file for halLiftover.

    Args:
        chrom: Genome sequence name.
        start: Region start position.
        end: Region end position.
        strand: Region strand; either '1' for plus strand or '-1' for minus strand.
        chrom_sizes: Mapping of genome sequence names to their lengths.
        bed_file: Path of BED file to output.
        flank_length: Length of upstream/downstream flanking regions to request.

    Raises:
        ValueError: If any region has an unknown genome sequence or invalid coordinates,
            or if ``flank_length`` is negative.
    """
    if flank_length < 0:
        raise ValueError(f"'flank_length' must be greater than or equal to 0: {flank_length}")

    region = SimpleRegion.from_1_based_region_attribs(chrom, start, end, strand)

    with open(bed_file, "w") as f:
        name = "."
        score = 0  # halLiftover requires an integer score in BED input

        try:
            chrom_size = chrom_sizes[region.chrom]
        except KeyError as exc:
            raise ValueError(f"chromosome ID '{region.chrom}' not found in genome chrom sizes") from exc

        if region.start < 0:
            raise ValueError(f"region start must be greater than or equal to 0: {region.start}")

        if region.end > chrom_size:
            raise ValueError(
                f"region end ({region.end}) must not be greater than the"
                f" corresponding chromosome length ({region.chrom}: {chrom_size})"
            )

        flanked_start = max(0, region.start - flank_length)
        flanked_end = min(region.end + flank_length, chrom_size)

        fields = [
            region.chrom,
            flanked_start,
            flanked_end,
            name,
            score,
            region.strand,
        ]
        print("\t".join(str(x) for x in fields), file=f)
