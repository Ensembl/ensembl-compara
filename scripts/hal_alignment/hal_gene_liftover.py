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

"""Do a liftover between two haplotypes in a HAL file.

Examples::
    # Do a liftover from GRCh38 to CHM13 of the human INS gene
    # along with 5 kb upstream and downstream flanking regions.
    python hal_gene_liftover.py --src-region chr11:2159779-2161221:-1 \
        --flank 5000 input.hal GRCh38 CHM13 output.psl

    # Do a liftover from GRCh38 to CHM13 of the
    # features specified in an input BED file.
    python hal_gene_liftover.py --src-bed-file input.bed \
        --flank 5000 input.hal GRCh38 CHM13 output.psl

"""

from argparse import ArgumentParser
import os
from pathlib import Path
import re
import subprocess
from tempfile import TemporaryDirectory
from typing import Dict, Iterable, Mapping, NamedTuple, Union


class SimpleRegion(NamedTuple):
    """A simple region."""
    chr: str
    start: int
    end: int
    strand: str


def load_chr_sizes_from_string(chr_sizes_text: str) -> Dict[str, int]:
    """Load chromosome sizes from text.

    Args:
        chr_sizes_text: Input chromosome sizes text. This is expected to be in
            a headerless two-column tab-delimited text format, in which each
            row contains the name of a chromosome in the first column and the
            length of that chromosome in the second column.

    Returns:
        Dictionary mapping chromosome names to their lengths.

    """
    chr_sizes = {}
    for line in chr_sizes_text.splitlines():
        chr_name, chr_size = line.rstrip().split('\t')
        chr_sizes[chr_name] = int(chr_size)
    return chr_sizes


def make_src_region_file(regions: Iterable[SimpleRegion], genome_name: str, chr_sizes: Mapping[str, int],
                         bed_file: Union[Path, str], flank_length: int = 0) -> None:
    """Make source region file.

    The source region file is a 6-column BED file so it can include the region
    sequence, start and end positions, and strand. The 'name' and 'score' columns
    respectively contain the placeholder values '.' and '0'; the score must be an
    integer for compatibility with halLiftover.

    Args:
        regions: Regions to write to output file.
        genome_name: Genome for which the regions are specified.
        chr_sizes: Mapping of chromosome names to their lengths.
        bed_file: Path of BED file to output.
        flank_length: Length of upstream/downstream flanking regions to request.

    Raises:
        ValueError: If any region has an unknown chromosome or invalid coordinates,
            or if `flank_length` is negative.

    """
    if flank_length < 0:
        raise ValueError(f"'flank_length' must be greater than or equal to 0: {flank_length}")

    with open(bed_file, 'w') as f:
        name = '.'
        score = 0
        for region in regions:

            try:
                chr_size = chr_sizes[region.chr]
            except KeyError as e:
                raise ValueError(
                    f"chromosome ID '{region.chr}' not found in HAL genome '{genome_name}'") from e

            if region.start < 0:
                raise ValueError(f'region start must be greater than or equal to 0: {region.start}')

            if region.end > chr_size:
                raise ValueError(f'region end ({region.end}) must not be greater than the'
                                 f' corresponding chromosome length ({region.chr}: {chr_size})')

            flanked_start = max(0, region.start - flank_length)
            flanked_end = min(region.end + flank_length, chr_size)

            fields = [region.chr, flanked_start, flanked_end, name, score, region.strand]
            print('\t'.join(str(x) for x in fields), file=f)


def parse_region(region: str) -> SimpleRegion:
    """Parse a region string.

    Args:
        region: Region string.

    Returns:
        A SimpleRegion object.

    Raises:
        ValueError: If `region` is an invalid region string.

    """
    _strand_num_to_sign = {1: '+', -1: '-'}

    seq_region_regex = re.compile(
        r'^(?P<chr>[^:]+):(?P<start>[0-9]+)-(?P<end>[0-9]+):(?P<strand>.+)$'
    )
    match = seq_region_regex.match(region)

    try:
        region_chr = match['chr']  # type: ignore
        match_start = int(match['start'])  # type: ignore
        region_end = int(match['end'])  # type: ignore
        match_strand = match['strand']  # type: ignore
    except TypeError as e:
        raise ValueError(f"region '{region}' could not be parsed") from e

    if match_start < 1:
        raise ValueError(f'region start must be greater than or equal to 1: {match_start}')
    region_start = match_start - 1

    try:
        region_strand = _strand_num_to_sign[int(match_strand)]
    except (KeyError, ValueError) as e:
        raise ValueError(f"region '{region}' has invalid strand: '{match_strand}'") from e

    if region_start >= region_end:
        raise ValueError(f"region '{region}' has inverted/empty interval")

    return SimpleRegion(region_chr, region_start, region_end, region_strand)


def run_hal_liftover(hal_file: Union[Path, str], src_genome: str,
                     bed_file: Union[Path, str], dst_genome: str,
                     psl_file: Union[Path, str]) -> None:
    """Do HAL liftover and output result to a PSL file.

    This is analogous to the shell command::

        halLiftover --outPSL in.hal GRCh38 in.bed CHM13 stdout | pslPosTarget stdin out.psl

    The target genome strand is positive and implicit in the output PSL file.

    Args:
        hal_file: Input HAL file.
        src_genome: Source genome name.
        bed_file: Input BED file of source features to liftover. To obtain
            strand-aware results, this must include a 'strand' column.
        dst_genome: Destination genome name.
        psl_file: Output PSL file.

    Raises:
        RuntimeError: If halLiftover or pslPosTarget have nonzero return code.

    """
    cmd1 = ['halLiftover', '--outPSL', hal_file, src_genome, bed_file, dst_genome, 'stdout']
    cmd2 = ['pslPosTarget', 'stdin', psl_file]
    with subprocess.Popen(cmd1, stdout=subprocess.PIPE) as p1:
        with subprocess.Popen(cmd2, stdin=p1.stdout) as p2:
            p2.wait()
            if p2.returncode != 0:
                status_type = 'exit code' if p2.returncode > 0 else 'signal'
                raise RuntimeError(
                    f'pslPosTarget terminated with {status_type} {abs(p2.returncode)}')
        p1.wait()
        if p1.returncode != 0:
            status_type = 'exit code' if p1.returncode > 0 else 'signal'
            raise RuntimeError(
                f'halLiftover terminated with {status_type} {abs(p1.returncode)}')


if __name__ == '__main__':

    parser = ArgumentParser(description='Performs a gene liftover between two haplotypes in a HAL file.')
    parser.add_argument('hal_file', help="Input HAL file.")
    parser.add_argument('src_genome', help="Source genome name.")
    parser.add_argument('dst_genome', help="Destination genome name.")
    parser.add_argument('output_file', help="Output PSL file.")

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--src-region', help="Region to liftover.")

    parser.add_argument('--flank', default=0, type=int,
                        help="Requested length of upstream/downstream"
                             " flanking regions to include in query.")

    args = parser.parse_args()

    source_chr_sizes_text = subprocess.check_output(['halStats', '--chromSizes', args.src_genome,
                                                     args.hal_file], text=True, encoding='ascii')
    source_chr_sizes = load_chr_sizes_from_string(source_chr_sizes_text)

    src_regions = [parse_region(args.src_region)]

    with TemporaryDirectory() as tmp_dir:

        src_bed_file = os.path.join(tmp_dir, 'src_regions.bed')
        make_src_region_file(src_regions, args.src_genome, source_chr_sizes, src_bed_file,
                             flank_length=args.flank)

        run_hal_liftover(args.hal_file, args.src_genome, src_bed_file, args.dst_genome, args.output_file)
