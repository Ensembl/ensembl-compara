#!/usr/bin/env python3

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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

"""Do a liftover between two haplotypes in a HAL file.

Examples:
    # Do a liftover from GRCh38 to CHM13 of the human INS gene
    # along with 5 kb upstream and downstream flanking regions.
    python hal_gene_liftover.py --region chr11:2159779-2161221:-1 \
        --flank 5000 input.hal GRCh38 CHM13 output.psl
"""

from argparse import ArgumentParser
from pathlib import Path
import re
from subprocess import PIPE, Popen
from tempfile import TemporaryDirectory
from typing import Tuple


def parse_region(region: str) -> Tuple[str, int, int, str]:
    """Parse a region string.

    Args:
        region: Region string.

    Returns:
        A tuple of parsed region elements.

    Raises:
        ValueError: If `region` is an invalid region string.
    """
    seq_region_regex = re.compile(
        '^(?P<chrom>[^:]+):(?P<start>[0-9]+)-(?P<end>[0-9]+):(?P<strand>1|-1)$'
    )
    match = seq_region_regex.match(region)

    try:
        region_chrom = match['chrom']  # type: ignore
        match_start = match['start']  # type: ignore
        match_end = match['end']  # type: ignore
        match_strand = match['strand']  # type: ignore
    except TypeError as e:
        raise ValueError(f"region '{region}' could not be parsed") from e

    region_start = int(match_start) - 1
    region_end = int(match_end)
    region_strand = '-' if match_strand == '-1' else '+'

    if region_start >= region_end:
        raise ValueError(f"region '{region}' has inverted/empty interval")

    return region_chrom, region_start, region_end, region_strand


if __name__ == '__main__':

    parser = ArgumentParser()
    parser.add_argument('hal_file', help="Input HAL file.")
    parser.add_argument('src_genome', help="Source genome name.")
    parser.add_argument('dest_genome', help="Destination genome name.")
    parser.add_argument('output_file', help="Output file.")
    parser.add_argument('--region', required=True, help="Region to liftover.")
    parser.add_argument('--flank', default=0, type=int,
                        help="Requested length of upstream/downstream"
                             " flanking regions to include in query.")

    args = parser.parse_args()

    hal_file = args.hal_file
    src_genome = args.src_genome
    dest_genome = args.dest_genome
    output_file = args.output_file
    region_string = args.region
    flank_length = args.flank


    if flank_length < 0:
        raise ValueError(f'invalid flank length: {flank_length}')

    with TemporaryDirectory() as tmp_dir_name:
        tmp_dir = Path(tmp_dir_name)

        src_bed_file = tmp_dir / 'src_regions.bed'

		# TODO: validate chromosome coords
        chrom, chrom_start, chrom_end, strand = parse_region(region_string)
        
        # TODO: clip flanked region at chromosome ends
        flanked_start = chrom_start - flank_length
        flanked_end = chrom_end + flank_length

        with open(src_bed_file, 'w') as f:
            name = '.'
            score = 0  # halLiftover requires an integer score in BED input
            fields = [chrom, flanked_start, flanked_end, name, score, strand]
            print('\t'.join(str(x) for x in fields), file=f)

        cmd1 = ['halLiftover', '--outPSL', hal_file, src_genome, src_bed_file, dest_genome,
                'stdout']
        cmd2 = ['pslPosTarget', 'stdin', output_file]
        p1 = Popen(cmd1, stdout=PIPE)
        p2 = Popen(cmd2, stdin=p1.stdout)
        p2.wait()
