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
    python hal_gene_liftover.py --src-region 'chr11:2159779-2161221:-' \
        --flank 5000 input.hal GRCh38 CHM13 output.json

    # Do a liftover from GRCh38 to CHM13 of the
    # features specified in an input BED file.
    python hal_gene_liftover.py --src-bed-file input.bed \
        --flank 5000 input.hal GRCh38 CHM13 output.json

"""

from argparse import ArgumentParser
from collections import defaultdict, OrderedDict
import io
import json
import os
from pathlib import Path
import re
from subprocess import PIPE, Popen, run
from tempfile import TemporaryDirectory
from typing import AbstractSet, Dict, Iterable, Mapping, NamedTuple, Set, Union

from Bio.SeqIO.FastaIO import SimpleFastaParser
import pybedtools  # type: ignore


class StrandedRegion(NamedTuple):
    """A stranded DNA sequence region."""
    chrom: str
    start: int
    end: int
    strand: str


class UnstrandedRegion(NamedTuple):
    """An unstranded DNA sequence region."""
    chrom: str
    start: int
    end: int


def convert_liftover_chain_to_bed(in_chain_file: Union[Path, str],
                                  region_mapping: Mapping[UnstrandedRegion, AbstractSet[StrandedRegion]],
                                  out_bed_file: Union[Path, str]) -> None:
    """Extract target regions from chain file and write to BED format.

    Args:
        in_chain_file: Input chain file.
        region_mapping: Dictionary mapping query regions to input regions.
        out_bed_file: Output BED file of aligned intervals in target genome.

    """
    field_types = OrderedDict([
        ('score', float),
        ('tName', str),
        ('tSize', int),
        ('tStrand', str),
        ('tStart', int),
        ('tEnd', int),
        ('qName', str),
        ('qSize', int),
        ('qStrand', str),
        ('qStart', int),
        ('qEnd', int),
        ('id', str)
    ])
    field_names = list(field_types.keys())

    with open(in_chain_file) as in_f, open(out_bed_file, 'w') as out_f:

        score = 0
        for line in in_f:
            if not line.startswith('chain'):
                continue
            field_values = line.rstrip().split()
            rec = {
                k: field_types[k](x) for k, x in zip(field_names, field_values[1:])
            }

            q_chrom = rec['qName']
            if rec['qStrand'] == '+':
                q_start = rec['qStart']
                q_end = rec['qEnd']
                q_strand = '+'
            else:
                q_start = rec['qSize'] - rec['qEnd']
                q_end = rec['qSize'] - rec['qStart']
                q_strand = '-'
            q_region = UnstrandedRegion(q_chrom, q_start, q_end)

            assert rec['tStrand'] == '+', 'chain target strand must be positive'
            t_chrom = rec['tName']
            t_start = rec['tStart']
            t_end = rec['tEnd']

            for i_chrom, i_start, i_end, i_strand in region_mapping[q_region]:
                # q_strand represents the relative strand of the query and target regions,
                # so the target strand is determined by whether q_strand matches i_strand
                t_strand = '+' if i_strand == q_strand else '-'

                t_strand_num = 1 if t_strand == '+' else -1
                i_strand_num = 1 if i_strand == '+' else -1

                t_region_name = f'{t_chrom}:{t_start + 1}-{t_end}:{t_strand_num}'
                i_region_name = f'{i_chrom}:{i_start + 1}-{i_end}:{i_strand_num}'
                name = f'{t_region_name}|{i_region_name}'

                fields = [t_chrom, t_start, t_end, name, score, t_strand]
                print('\t'.join(str(x) for x in fields), file=out_f)


def convert_liftover_fasta_to_json(in_fasta_file: Union[Path, str],
                                   source_genome: str,
                                   destination_genome: str,
                                   out_json_file: Union[Path, str],
                                   flank_length: int = 0) -> None:
    """Convert liftover FASTA file to JSON format.

    Args:
        in_fasta_file: Input FASTA file.
        source_genome: Name of source genome.
        destination_genome: Name of destination genome.
        out_json_file: Output JSON file.
        flank_length: Length of upstream/downstream flanking regions to request.

    """

    src_to_dest = defaultdict(list)
    with open(in_fasta_file) as f:
        for header, sequence in SimpleFastaParser(f):
            output_region, input_region = (parse_region(x) for x in header.split('|'))
            out_start_pos = output_region.start + 1
            out_end_pos = output_region.end
            out_strand_num = 1 if output_region.strand == '+' else -1
            src_to_dest[input_region].append({
                'dest_chrom': output_region.chrom,
                'dest_start': out_start_pos,
                'dest_end': out_end_pos,
                'dest_strand': out_strand_num,
                'dest_sequence': sequence
            })

    data = list()
    for input_region, results in src_to_dest.items():
        in_start_pos = input_region.start + 1
        in_end_pos = input_region.end
        in_strand_num = 1 if input_region.strand == '+' else -1
        params = {
            'src_genome': source_genome,
            'src_chrom': input_region.chrom,
            'src_start': in_start_pos,
            'src_end': in_end_pos,
            'src_strand': in_strand_num,
            'flank': flank_length,
            'dest_genome': destination_genome
        }
        data.append({
            'params': params,
            'results': results
        })

    with open(out_json_file, 'w') as f:
        json.dump(data, f)


def export_2bit_file(in_hal_file: Union[Path, str], genome_name: str,
                     out_2bit_file: Union[Path, str]) -> None:
    """Export genome assembly sequences in 2bit format.

    Args:
        in_hal_file: Input HAL file.
        genome_name: Name of genome to export.
        out_2bit_file: Output 2bit file.

    Raises:
        RuntimeError: If hal2fasta or faToTwoBit have nonzero return code.

    """
    cmd1 = ['hal2fasta', in_hal_file, genome_name]
    cmd2 = ['faToTwoBit', 'stdin', out_2bit_file]
    with Popen(cmd1, stdout=PIPE) as p1:
        with Popen(cmd2, stdin=p1.stdout) as p2:
            p2.wait()
            if p2.returncode != 0:
                status_type = 'exit code' if p2.returncode > 0 else 'signal'
                raise RuntimeError(
                    f'faToTwoBit terminated with {status_type} {abs(p2.returncode)}')
        p1.wait()
        if p1.returncode != 0:
            status_type = 'exit code' if p1.returncode > 0 else 'signal'
            raise RuntimeError(
                f'hal2fasta terminated with {status_type} {abs(p1.returncode)}')


def load_chrom_sizes(in_2bit_file: Union[Path, str]) -> Dict[str, int]:
    """Load chromosome sizes from a 2bit file.

    Args:
        in_2bit_file: Input 2bit file.

    Returns:
        Dictionary mapping chromosome names to their lengths.

    """
    cmd = ['twoBitInfo', in_2bit_file, 'stdout']
    process = run(cmd, stdout=PIPE, check=True)
    text = process.stdout.decode('ascii')

    chrom_sizes = dict()
    with io.StringIO(text) as stream:
        for line in stream:
            chrom, chrom_size = line.rstrip().split('\t')
            chrom_sizes[chrom] = int(chrom_size)

    return chrom_sizes


def make_src_region_file(regions: Iterable[Union[pybedtools.cbedtools.Interval, StrandedRegion]],
                         chrom_sizes: Mapping[str, int],
                         bed_file: Union[Path, str],
                         flank_length: int = 0) -> Dict[UnstrandedRegion, Set[StrandedRegion]]:
    """Make source region file.

    Args:
        regions: Regions from which to generate output BED file.
        chrom_sizes: Dictionary mapping chromosome names to their lengths.
        bed_file: Path of BED file to output.
        flank_length: Length of upstream/downstream flanking regions to request.

    Returns:
        Dictionary mapping query regions to input regions.

    Raises:
        ValueError: If any region has an unknown chromosome or invalid coordinates.

    """
    region_mapping: Dict[UnstrandedRegion, Set[StrandedRegion]] = dict()
    with open(bed_file, 'w') as f:
        name = '.'
        score = 0  # halLiftover requires an integer score in BED input
        for region in regions:

            try:
                chrom_size = chrom_sizes[region.chrom]
            except KeyError as e:
                raise ValueError(f"region has unknown chromosome: '{region.chrom}'") from e

            if region.start < 0:
                raise ValueError(f'region start must be greater than or equal to 0: {region.start}')

            if region.end > chrom_size:
                raise ValueError(f'region end ({region.end}) must not be greater'
                                 f' than chromosome length ({chrom_size})')

            flanked_start = max(0, region.start - flank_length)
            flanked_end = min(region.end + flank_length, chrom_size)

            fields = [region.chrom, flanked_start, flanked_end, name, score, region.strand]
            print('\t'.join(str(x) for x in fields), file=f)

            # We do not specify strand for the query region, as this info
            # is not completely preserved during the liftover process.
            query_region = UnstrandedRegion(region.chrom, flanked_start, flanked_end)
            input_region = StrandedRegion(region.chrom, region.start, region.end, region.strand)
            try:
                region_mapping[query_region].add(input_region)
            except KeyError:
                region_mapping[query_region] = set([input_region])

    return region_mapping


def parse_region(region: str) -> StrandedRegion:
    """Parse a region string.

    Args:
        region: Region string.

    Returns:
        A StrandedRegion object.

    Raises:
        ValueError: If `region` is an invalid region string.

    """
    seq_region_regex = re.compile(
        r'^(?P<chrom>[^:]+):(?P<start>[0-9]+)-(?P<end>[0-9]+):(?P<strand>1|-1)$'
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
    region_strand = '+' if match_strand == '1' else '-'

    if region_start >= region_end:
        raise ValueError(f"region '{region}' has inverted/empty interval")

    return StrandedRegion(region_chrom, region_start, region_end, region_strand)


def run_axt_chain(in_psl_file: Union[Path, str], query_2bit_file: Union[Path, str],
                  target_2bit_file: Union[Path, str], out_chain_file: Union[Path, str],
                  linear_gap: Union[Path, str] = 'medium') -> None:
    """Run axtChain on PSL file.

    Args:
        in_psl_file: Input PSL file.
        query_2bit_file: Query 2bit file.
        target_2bit_file: Target 2bit file.
        out_chain_file: Output chain file.
        linear_gap: axtChain linear gap parameter.

    """
    cmd = ['axtChain', '-psl', f'-linearGap={linear_gap}', in_psl_file, target_2bit_file,
           query_2bit_file, out_chain_file]
    run(cmd, check=True)


def run_hal_liftover(in_hal_file: Union[Path, str], query_genome: str,
                     in_bed_file: Union[Path, str], target_genome: str,
                     out_psl_file: Union[Path, str]) -> None:
    """Do HAL liftover and output result to a PSL file.

    This is analogous to the shell command::

        halLiftover --outPSL in.hal GRCh38 in.bed CHM13 stdout | pslPosTarget stdin out.psl

    The target genome strand is positive and implicit in the output PSL file.

    Args:
        in_hal_file: Input HAL file.
        query_genome: Source genome name.
        in_bed_file: Input BED file of source features to liftover. To obtain
                     strand-aware results, this must include a 'strand' column.
        target_genome: Target genome name.
        out_psl_file: Output PSL file.

    Raises:
        RuntimeError: If halLiftover or pslPosTarget have nonzero return code.

    """
    cmd1 = ['halLiftover', '--outPSL', in_hal_file, query_genome, in_bed_file, target_genome,
            'stdout']
    cmd2 = ['pslPosTarget', 'stdin', out_psl_file]
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


def run_two_bit_to_fa(in_bed_file: Union[Path, str], in_2bit_file: Union[Path, str],
                      out_fasta_file: Union[Path, str]) -> None:
    """Run twoBitToFa to obtain sequences of aligned target regions.

    Args:
        in_bed_file: Input BED file.
        in_2bit_file: Input 2bit file.
        out_fasta_file: Output FASTA file.

    """
    cmd = ['twoBitToFa', f'-bed={in_bed_file}', in_2bit_file, out_fasta_file]
    run(cmd, check=True)


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
    parser.add_argument('--linear-gap', default='medium',
                        help="axtChain linear gap parameter.")

    args = parser.parse_args()

    hal_file = args.hal_file
    src_genome = args.src_genome
    dest_genome = args.dest_genome
    src_region = args.src_region
    src_bed_file = args.src_bed_file
    flank = args.flank


    if flank < 0:
        raise ValueError(f'Flank length must be greater than or equal to 0: {flank}')

    hal_file_stem, hal_file_ext = os.path.splitext(hal_file)
    hal_aux_dir = f'{hal_file_stem}_files'
    os.makedirs(hal_aux_dir, exist_ok=True)

    src_2bit_file = os.path.join(hal_aux_dir, f'{src_genome}.2bit')
    if not os.path.isfile(src_2bit_file):
        export_2bit_file(hal_file, src_genome, src_2bit_file)

    dest_2bit_file = os.path.join(hal_aux_dir, f'{dest_genome}.2bit')
    if not os.path.isfile(dest_2bit_file):
        export_2bit_file(hal_file, dest_genome, dest_2bit_file)

    with TemporaryDirectory() as tmp_dir:

        if src_region is not None:
            src_regions = [parse_region(src_region)]
        else:  # i.e. bed_file is not None
            src_regions = pybedtools.BedTool(src_bed_file)

        src_chrom_sizes = load_chrom_sizes(src_2bit_file)

        query_bed_file = os.path.join(tmp_dir, 'src_regions.bed')
        region_map = make_src_region_file(src_regions, src_chrom_sizes, query_bed_file,
                                          flank_length=flank)

        psl_file = os.path.join(tmp_dir, 'alignment.psl')
        run_hal_liftover(hal_file, src_genome, query_bed_file, dest_genome, psl_file)

        chain_file = os.path.join(tmp_dir, 'alignment.chain')
        run_axt_chain(psl_file, src_2bit_file, dest_2bit_file, chain_file,
                      linear_gap=args.linear_gap)

        chain_bed_file = os.path.join(tmp_dir, 'chain.bed')
        convert_liftover_chain_to_bed(chain_file, region_map, chain_bed_file)

        chain_fasta_file = os.path.join(tmp_dir, 'chain.fa')
        run_two_bit_to_fa(chain_bed_file, dest_2bit_file, chain_fasta_file)

        convert_liftover_fasta_to_json(chain_fasta_file, src_genome, dest_genome,
                                       args.output_file, flank_length=flank)
