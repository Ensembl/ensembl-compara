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
from subprocess import PIPE, Popen
from tempfile import TemporaryDirectory
from typing import Iterable, NamedTuple, Union

import pybedtools  # type: ignore


class SimpleRegion(NamedTuple):
    """A simple region."""
    chrom: str
    start: int
    end: int
    strand: str


def make_src_region_file(regions: Iterable[Union[pybedtools.cbedtools.Interval, SimpleRegion]],
                         bed_file: Union[Path, str], flank_length: int = 0) -> None:
    """Make source region file.

    Args:
        regions: Regions to write to output file.
        bed_file: Path of BED file to output.
        flank_length: Length of upstream/downstream flanking regions to request.

    Raises:
        ValueError: If `flank_length` is negative.

    """
    if flank_length < 0:
        raise ValueError(f"'flank_length' must be greater than or equal to 0: {flank_length}")

    with open(bed_file, 'w') as f:
        name = '.'
        score = 0  # halLiftover requires an integer score in BED input
        for region in regions:
            flanked_start = region.start - flank_length
            flanked_end = region.end + flank_length
            fields = [region.chrom, flanked_start, flanked_end, name, score, region.strand]
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
    seq_region_regex = re.compile(
        r'^(?P<chrom>[^:]+):(?P<start>[0-9]+)-(?P<end>[0-9]+):(?P<strand>.+)$'
    )
    match = seq_region_regex.match(region)

    try:
        region_chrom = match['chrom']  # type: ignore
        match_start = int(match['start'])  # type: ignore
        region_end = int(match['end'])  # type: ignore
        match_strand = match['strand']  # type: ignore
    except TypeError as e:
        raise ValueError(f"region '{region}' could not be parsed") from e

    if match_start < 1:
        raise ValueError(f'region start must be greater than or equal to 1: {match_start}')
    region_start = match_start - 1

    if match_strand == '1':
        region_strand = '+'
    elif match_strand == '-1':
        region_strand = '-'
    else:
        raise ValueError(f"region '{region}' has invalid strand: '{match_strand}'")

    if region_start >= region_end:
        raise ValueError(f"region '{region}' has inverted/empty interval")

    return SimpleRegion(region_chrom, region_start, region_end, region_strand)


if __name__ == '__main__':

    parser = ArgumentParser(description='Performs a gene liftover between two haplotypes in a HAL file.')
    parser.add_argument('hal_file', help="Input HAL file.")
    parser.add_argument('src_genome', help="Source genome name.")
    parser.add_argument('dest_genome', help="Destination genome name.")
    parser.add_argument('output_file', help="Output file.")

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--src-region', help="Region to liftover.")
    group.add_argument('--src-bed-file', help="BED file containing regions to liftover.")

    parser.add_argument('--flank', default=0, type=int,
                        help="Requested length of upstream/downstream"
                             " flanking regions to include in query.")

    args = parser.parse_args()

    hal_file = args.hal_file
    src_genome = args.src_genome
    dest_genome = args.dest_genome
    output_file = args.output_file
    src_region = args.src_region
    src_bed_file = args.src_bed_file
    flank = args.flank


    with TemporaryDirectory() as tmp_dir:

        query_bed_file = os.path.join(tmp_dir, 'src_regions.bed')

        if src_region is not None:
            src_regions = [parse_region(src_region)]
        else:  # i.e. bed_file is not None
            src_regions = pybedtools.BedTool(src_bed_file)

        make_src_region_file(src_regions, query_bed_file, flank_length=flank)

        # halLiftover --outPSL in.hal GRCh38 in.bed CHM13 stdout | pslPosTarget stdin out.psl
        cmd1 = ['halLiftover', '--outPSL', hal_file, src_genome, query_bed_file, dest_genome,
                'stdout']
        cmd2 = ['pslPosTarget', 'stdin', output_file]
        with Popen(cmd1, stdout=PIPE) as p1:
            with Popen(cmd2, stdin=p1.stdout) as p2:
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
