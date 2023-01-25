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
    python hal_gene_liftover.py --src-region 'chr11:2159779-2161221:-1' \
        --flank 5000 input.hal GRCh38 CHM13 output.json

    # Do a liftover from GRCh38 to CHM13 of the
    # features specified in an input BED file.
    python hal_gene_liftover.py --src-bed-file input.bed \
        --flank 5000 input.hal GRCh38 CHM13 output.json

"""

from __future__ import annotations
from argparse import ArgumentParser
import csv
from dataclasses import dataclass, InitVar
import json
import os
from pathlib import Path
import re
import shutil
from subprocess import PIPE, Popen, run
from tempfile import TemporaryDirectory
from typing import Any, Dict, Generator, Iterable, List, Mapping, Tuple, Union

from Bio.SeqIO.FastaIO import SimpleFastaParser


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
                raise ValueError(f"0-based region start must be greater than or equal to 0: {self.start}")

            if self.start >= self.end:
                raise ValueError(
                    f"0-based region end ({self.end}) must be greater than region start ({self.start})")

            if self.strand not in ('+', '-'):
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
            r'^(?P<chr>[^:]+):(?P<start>[0-9]+)-(?P<end>[0-9]+):(?P<strand>.+)$'
        )
        match = seq_region_regex.match(region_string)

        try:
            chr_ = match['chr']  # type: ignore
            start = match['start']  # type: ignore
            end = match['end']  # type: ignore
            strand = match['strand']  # type: ignore
        except TypeError as e:
            raise ValueError(f"failed to tokenise 1-based region string: '{region_string}'") from e

        return cls.from_1_based_region_attribs(chr_, start, end, strand)

    @classmethod
    def from_1_based_region_attribs(cls, chr_: str, start: Union[int, str], end: Union[int, str],
                                    strand: Union[int, str]) -> SimpleRegion:
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
        _strand_num_to_sign = {1: '+', -1: '-'}

        start = int(start)
        end = int(end)

        if start < 1:
            raise ValueError(f'1-based region start must be greater than or equal to 1: {start}')

        if start > end:
            raise ValueError(
                f'1-based region end ({end}) must be greater than or equal to region start ({start})')

        try:
            strand = _strand_num_to_sign[int(strand)]
        except (KeyError, ValueError) as e:
            raise ValueError(f"1-based region has invalid strand: '{strand}'") from e

        return cls(chr_, start - 1, end, strand, validate=False)

    def to_1_based_region_string(self):
        """Get the 1-based region string corresponding to this region."""
        strand_num = 1 if self.strand == '+' else -1
        return f'{self.chr}:{self.start + 1}-{self.end}:{strand_num}'


class UnixTab(csv.unix_dialect):
    """A tab-delimited Unix csv dialect."""
    delimiter = '\t'


def export_2bit_file(hal_file: Union[Path, str], genome_name: str,
                     two_bit_file: Union[Path, str]) -> None:
    """Export genome assembly sequences in 2bit format.

    This is analogous to the shell command::

        hal2fasta in.hal GRCh38 | faToTwoBit stdin GRCh38.2bit

    Args:
        hal_file: Input HAL file.
        genome_name: Name of genome to export.
        two_bit_file: Output 2bit file.

    Raises:
        RuntimeError: If hal2fasta or faToTwoBit have nonzero return code.

    """
    cmd1 = ['hal2fasta', hal_file, genome_name]
    cmd2 = ['faToTwoBit', 'stdin', two_bit_file]
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


def extract_liftover_regions_from_bed(bed_file: Union[Path, str]) -> List[SimpleRegion]:
    """Extract liftover destination regions from a BED file.

    Args:
        bed_file: Input BED file.

    Returns:
        List of liftover destination regions.

    """
    dst_regions = []
    with open(bed_file) as f:
        for line in f:
            chr_, start, end, _name, _score, strand, *_unused = line.rstrip().split('\t')
            dst_regions.append(SimpleRegion(chr_, int(start), int(end), strand))

    return dst_regions


def extract_liftover_regions_from_chain(src_region: SimpleRegion, chain_file: Union[Path, str]
                                        ) -> Tuple[List[SimpleRegion], List[SimpleRegion]]:
    """Extract liftover regions from a chain file.

    Args:
        src_region: Liftover source region.
        chain_file: Chain file of liftover alignments.

    Returns:
        Tuple of two lists containing the lifted-over
        source and destination regions, respectively.

    """
    field_names = ['score', 'tName', 'tSize', 'tStrand', 'tStart', 'tEnd',
                   'qName', 'qSize', 'qStrand', 'qStart', 'qEnd', 'id']

    chain_src_regions = []
    chain_dest_regions = []
    with open(chain_file) as f:
        for line in f:
            if not line.startswith('chain'):
                continue
            field_values = line.rstrip().split()
            rec = dict(zip(field_names, field_values[1:]))

            src_chr = rec['qName']
            src_start = int(rec['qStart'])
            src_end = int(rec['qEnd'])
            src_strand = src_region.strand
            chain_src_regions.append(SimpleRegion(src_chr, src_start, src_end, src_strand))

            dest_chr = rec['tName']
            dest_start = int(rec['tStart'])
            dest_end = int(rec['tEnd'])

            # rec['qStrand'] represents the relative strand of the source and target regions,
            # so the target strand is determined by whether rec['qStrand'] matches src_strand
            assert rec['tStrand'] == '+', 'chain target strand must be positive'
            dest_strand = '+' if src_strand == rec['qStrand'] else '-'

            chain_dest_regions.append(SimpleRegion(dest_chr, dest_start, dest_end, dest_strand))

    return chain_src_regions, chain_dest_regions


def extract_region_sequences(regions: Iterable[SimpleRegion],
                             two_bit_file: Union[Path, str]) -> List[str]:
    """Extract region sequences from a 2bit file.

    Args:
        regions: Regions to extract.
        two_bit_file: 2bit sequence file.

    Returns:
        List of region sequences.

    """
    with TemporaryDirectory() as tmp_dir:

        chain_bed_file = os.path.join(tmp_dir, 'chain.bed')
        with open(chain_bed_file, 'w') as f:
            for idx, region in enumerate(regions):
                fields = [region.chr, region.start, region.end, idx, 0, region.strand]
                print('\t'.join(str(x) for x in fields), file=f)

        chain_fasta_file = os.path.join(tmp_dir, 'chain.fa')
        run_two_bit_to_fa(chain_bed_file, two_bit_file, chain_fasta_file)

        with open(chain_fasta_file) as f:
            sequences = [seq for _, seq in SimpleFastaParser(f)]

    return sequences


def liftover_via_chain(src_region: SimpleRegion, src_genome: str, src_chr_sizes: Dict[str, int],
                       dst_genome: str, dst_2bit_file: Union[Path, str], chain_file: Union[Path, str],
                       flank_length: int = 0) -> Dict[str, Any]:
    """Liftover a region using a pairwise assembly chain file.

    Args:
        src_region: Region to liftover.
        src_genome: Source genome.
        src_chr_sizes: Source genome chromosome name-to-length mapping.
        dst_genome: Destination genome.
        dst_2bit_file: 2bit file of destination genome sequences.
        chain_file: Input pairwise assembly chain file.
        flank_length: Length of upstream/downstream flanking regions to request.

    Returns:
        Dictionary containing liftover parameters and results.

    """
    _strand_sign_to_num = {'+': 1, '-': -1}

    rec: Dict[str, Any] = {}
    rec['params'] = {
        'src_genome': src_genome,
        'src_chr': src_region.chr,
        'src_start': src_region.start + 1,
        'src_end': src_region.end,
        'src_strand': _strand_sign_to_num[src_region.strand],
        'flank': flank_length,
        'dest_genome': dst_genome
    }

    rec['results'] = []
    with TemporaryDirectory() as tmp_dir:

        src_bed_file = os.path.join(tmp_dir, 'src_regions.bed')
        make_src_region_file([src_region], src_genome, src_chr_sizes, src_bed_file,
                             flank_length=flank_length)

        dst_bed_file = os.path.join(tmp_dir, 'dst_regions.bed')
        run(['liftOver', '-multiple', src_bed_file, chain_file, dst_bed_file, os.devnull], check=True)

        dst_regions = extract_liftover_regions_from_bed(dst_bed_file)

        if not dst_regions:
            return rec

        dst_sequences = extract_region_sequences(dst_regions, dst_2bit_file)

        for dst_region, dst_sequence in zip(dst_regions, dst_sequences):
            rec['results'].append({
                'dest_chr': dst_region.chr,
                'dest_start': dst_region.start + 1,
                'dest_end': dst_region.end,
                'dest_strand': _strand_sign_to_num[dst_region.strand],
                'dest_sequence': dst_sequence
            })

    return rec


def liftover_via_hal(src_region: SimpleRegion, src_genome: str, src_2bit_file: Union[Path, str],
                     src_chr_sizes: Dict[str, int], dest_genome: str, dest_2bit_file: Union[Path, str],
                     hal_file: Union[Path, str], flank_length: int = 0, skip_chain: bool = False,
                     linear_gap: Union[Path, str] = 'medium') -> Dict[str, Any]:
    """Liftover a region using a HAL file.

    Args:
        src_region: Region to liftover.
        src_genome: Source genome.
        src_2bit_file: 2bit file of source genome sequences.
        src_chr_sizes: Source genome chromosome name-to-length mapping.
        dest_genome: Destination genome.
        dest_2bit_file: 2bit file of destination genome sequences.
        hal_file: Input HAL file.
        flank_length: Length of upstream/downstream flanking regions to request.
        skip_chain: Set to True to skip chaining of liftover alignment regions.
        linear_gap: axtChain linear gap parameter.

    Returns:
        Dictionary containing liftover parameters and results.

    """
    _strand_sign_to_num = {'+': 1, '-': -1}

    rec: Dict[str, Any] = {}
    rec['params'] = {
        'src_genome': src_genome,
        'src_chr': src_region.chr,
        'src_start': src_region.start + 1,
        'src_end': src_region.end,
        'src_strand': _strand_sign_to_num[src_region.strand],
        'flank': flank_length,
        'dest_genome': dest_genome
    }

    rec['results'] = []
    with TemporaryDirectory() as tmp_dir:

        src_bed_file = os.path.join(tmp_dir, 'src_regions.bed')
        make_src_region_file([src_region], src_genome, src_chr_sizes, src_bed_file,
                             flank_length=flank_length)

        psl_file = os.path.join(tmp_dir, 'alignment.psl')
        run_hal_liftover(hal_file, src_genome, src_bed_file, dest_genome, psl_file)

        if os.path.getsize(psl_file) == 0:
            return rec

        chain_file = os.path.join(tmp_dir, 'alignment.chain')
        if skip_chain:
            run_psl_to_chain(psl_file, chain_file)
        else:
            run_axt_chain(psl_file, dest_2bit_file, src_2bit_file, chain_file, linear_gap=linear_gap)

        lifted_src_regions, dest_regions = extract_liftover_regions_from_chain(src_region, chain_file)

        if not dest_regions:
            return rec

        dest_sequences = extract_region_sequences(dest_regions, dest_2bit_file)

        for lifted_src_region, dest_region, dest_sequence in zip(lifted_src_regions, dest_regions,
                                                                 dest_sequences):
            rec['results'].append({
                'lifted_src_chr': lifted_src_region.chr,
                'lifted_src_start': lifted_src_region.start + 1,
                'lifted_src_end': lifted_src_region.end,
                'lifted_src_strand': _strand_sign_to_num[src_region.strand],
                'dest_chr': dest_region.chr,
                'dest_start': dest_region.start + 1,
                'dest_end': dest_region.end,
                'dest_strand': _strand_sign_to_num[dest_region.strand],
                'dest_sequence': dest_sequence
            })

    return rec


def load_liftover_alt_synonyms(alt_synonym_json_file: Union[Path, str], src_genome: str,
                               dest_genome: str) -> Tuple[Dict, Dict, Dict]:
    """Load liftover alt-synonym data from JSON file.

    Args:
        alt_synonym_json_file: Input JSON file containing a mapping of each genome name in a HAL file to its
            alt-synonym mapping object. In the alt-synonym mapping of a genome, each key is a chromosome name,
            and its corresponding 'alternative name' value is the name of that chromosome within the HAL file.
        src_genome: Source genome.
        dest_genome: Destination genome.

    Returns:
        A tuple of the three alt-synonym mappings that are useful for liftover:
        the source genome forward mapping (chromosome name to alternative name),
        the source genome reverse mapping (alternative name to chromosome name),
        and the destination genome reverse mapping.

    Raises:
        ValueError: If a genome alt-synonym mapping is not a one-to-one mapping.

    """
    with open(alt_synonym_json_file) as f:
        alt_synonym_data = json.load(f)

    fwd_maps = {}
    rev_maps = {}
    for genome in (src_genome, dest_genome):
        fwd_maps[genome] = alt_synonym_data[genome]
        rev_maps[genome] = {x: k for k, x in fwd_maps[genome].items()}
        if len(rev_maps[genome]) != len(fwd_maps[genome]):
            raise ValueError(f"alt-synonym mapping is not one-to-one for HAL genome '{genome}'")

    return fwd_maps[src_genome], rev_maps[src_genome], rev_maps[dest_genome]


def load_chr_sizes(hal_file: Union[Path, str], genome_name: str) -> Dict[str, int]:
    """Load chromosome sizes from an input HAL file.

    Args:
        hal_file: Input HAL file.
        genome_name: Name of the genome to get the chromosome sizes of.

    Returns:
        Dictionary mapping chromosome names to their lengths.

    """
    cmd = ['halStats', '--chromSizes', genome_name, hal_file]
    process = run(cmd, check=True, capture_output=True, text=True, encoding='ascii')

    chr_sizes = {}
    for line in process.stdout.splitlines():
        chr_name, chr_size = line.rstrip().split('\t')
        chr_sizes[chr_name] = int(chr_size)

    return chr_sizes


def make_chain_file(query_genome: str, query_2bit_file: Union[Path, str], query_chr_sizes: Dict[str, int],
                    target_genome: str, target_2bit_file: Union[Path, str], hal_file: Union[Path, str],
                    chain_file: Union[Path, str], linear_gap: Union[Path, str] = 'medium') -> None:
    """Make a pairwise assembly chain file from a HAL alignment.

    Args:
        query_genome: Query genome.
        query_2bit_file: 2bit file of query genome sequences.
        query_chr_sizes: Query genome chromosome name-to-length mapping.
        target_genome: Target genome.
        target_2bit_file: 2bit file of target genome sequences.
        hal_file: Input HAL file.
        chain_file: Output chain file.
        linear_gap: axtChain linear gap parameter.

    """
    query_regions = [SimpleRegion(k, 0, x, '+') for k, x in query_chr_sizes.items()]

    with TemporaryDirectory() as tmp_dir:

        query_bed_file = os.path.join(tmp_dir, 'query_regions.bed')
        make_src_region_file(query_regions, query_genome, query_chr_sizes, query_bed_file)

        tmp_psl_file = os.path.join(tmp_dir, 'alignment.psl')
        run_hal_liftover(hal_file, query_genome, query_bed_file, target_genome, tmp_psl_file)

        tmp_chain_file = os.path.join(tmp_dir, 'alignment.chain')
        run_axt_chain(tmp_psl_file, target_2bit_file, query_2bit_file, tmp_chain_file, linear_gap=linear_gap)

        shutil.move(tmp_chain_file, chain_file)


def make_src_region_file(regions: Iterable[SimpleRegion], genome: str, chr_sizes: Mapping[str, int],
                         bed_file: Union[Path, str], flank_length: int = 0) -> None:
    """Make source region file.

    Args:
        regions: Regions to write to output file.
        genome: Genome for which the regions are specified.
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
        score = 0  # halLiftover requires an integer score in BED input
        for region in regions:

            try:
                chr_size = chr_sizes[region.chr]
            except KeyError as e:
                raise ValueError(
                    f"chromosome ID '{region.chr}' not found in HAL genome '{genome}'") from e

            if region.start < 0:
                raise ValueError(f'region start must be greater than or equal to 0: {region.start}')

            if region.end > chr_size:
                raise ValueError(f'region end ({region.end}) must not be greater than the'
                                 f' corresponding chromosome length ({region.chr}: {chr_size})')

            flanked_start = max(0, region.start - flank_length)
            flanked_end = min(region.end + flank_length, chr_size)

            fields = [region.chr, flanked_start, flanked_end, name, score, region.strand]
            print('\t'.join(str(x) for x in fields), file=f)


def read_region_tsv_file(region_tsv_file: Union[Path, str]) -> Generator[SimpleRegion, None, None]:
    """Read region data from input TSV file.

    Args:
        region_tsv_file: Input TSV file containing 1-offset regions specified
            in columns with headings 'chr', 'start', 'end' and 'strand'.

    Yields:
        SimpleRegion: The region specified in the given row of the input TSV file.

    """
    with open(region_tsv_file) as f:
        reader = csv.DictReader(f, dialect=UnixTab)
        for row in reader:
            yield SimpleRegion.from_1_based_region_attribs(row['chr'], row['start'],
                                                           row['end'], row['strand'])


def run_axt_chain(psl_file: Union[Path, str], target_2bit_file: Union[Path, str],
                  query_2bit_file: Union[Path, str], chain_file: Union[Path, str],
                  linear_gap: Union[Path, str] = 'medium') -> None:
    """Run axtChain on PSL file.

    Args:
        psl_file: Input PSL file.
        target_2bit_file: Target 2bit file.
        query_2bit_file: Query 2bit file.
        chain_file: Output chain file.
        linear_gap: axtChain linear gap parameter.

    """
    cmd = ['axtChain', '-psl', f'-linearGap={linear_gap}', psl_file, target_2bit_file,
           query_2bit_file, chain_file]
    run(cmd, check=True)


def run_hal_liftover(hal_file: Union[Path, str], src_genome: str,
                     bed_file: Union[Path, str], dest_genome: str,
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
        dest_genome: Destination genome name.
        psl_file: Output PSL file.

    Raises:
        RuntimeError: If halLiftover or pslPosTarget have nonzero return code.

    """
    cmd1 = ['halLiftover', '--outPSL', hal_file, src_genome, bed_file, dest_genome, 'stdout']
    cmd2 = ['pslPosTarget', 'stdin', psl_file]
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


def run_psl_to_chain(psl_file: Union[Path, str], chain_file: Union[Path, str]) -> None:
    """Convert PSL file to chain format.

    Args:
        psl_file: Input PSL file.
        chain_file: Output chain file.

    """
    cmd = ['pslToChain', psl_file, chain_file]
    run(cmd, check=True)


def run_two_bit_to_fa(bed_file: Union[Path, str], two_bit_file: Union[Path, str],
                      fasta_file: Union[Path, str]) -> None:
    """Run twoBitToFa to obtain sequences of aligned target regions.

    Args:
        bed_file: Input BED file.
        two_bit_file: Input 2bit file.
        fasta_file: Output FASTA file.

    """
    cmd = ['twoBitToFa', f'-bed={bed_file}', two_bit_file, fasta_file]
    run(cmd, check=True)


if __name__ == '__main__':

    parser = ArgumentParser(description='Performs a gene liftover between two haplotypes in a HAL file.')
    parser.add_argument('hal_file', help="Input HAL file.")
    parser.add_argument('src_genome', help="Source genome name.")
    parser.add_argument('dest_genome', help="Destination genome name.")
    parser.add_argument('output_file', help="Output file.")

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--src-region', metavar='STR', help="Region to liftover.")
    group.add_argument('--src-region-tsv', metavar='FILE',
                       help="Input TSV file containing regions to liftover.")

    parser.add_argument('--flank', metavar='INT', default=0, type=int,
                        help="Requested length of upstream/downstream"
                             " flanking regions to include in query.")
    parser.add_argument('--linear-gap', metavar='STR|FILE', default='medium',
                        help="axtChain linear gap parameter.")

    parser.add_argument('--output-format', metavar='STR', default='JSON', choices=['JSON', 'TSV'],
                        help="Format of output file.")

    chain_params = parser.add_mutually_exclusive_group()
    chain_params.add_argument('--skip-chain', action='store_true',
                              help="Skip on-the-fly chaining of liftover alignment regions.")
    chain_params.add_argument('--cache-chain', action='store_true',
                              help="Use cached pairwise assembly chain file for"
                                   " liftover, generating the chain file if necessary.")

    parser.add_argument('--hal-aux-dir', metavar='PATH',
                        help="Directory in which HAL-derived data files are created (e.g. genome sequence"
                             " files). By default, the path of this directory is determined from the input"
                             " HAL file (e.g. '/path/to/aln.hal'), by replacing the HAL file extension with"
                             " the suffix '_files' (e.g. '/path/to/aln_files').")

    parser.add_argument('--alt-synonym-json', metavar='FILE',
                        help="Input JSON file with, for each genome in the HAL file, a one-to-one mapping"
                             " between each chromosome name and its alternative synonym in the HAL file.")
    args = parser.parse_args()

    if args.hal_aux_dir is not None:
        hal_aux_dir = args.hal_aux_dir
    else:
        hal_file_stem, _ = os.path.splitext(args.hal_file)
        hal_aux_dir = f'{hal_file_stem}_files'
    os.makedirs(hal_aux_dir, exist_ok=True)

    source_2bit_file = os.path.join(hal_aux_dir, f'{args.src_genome}.2bit')
    if not os.path.isfile(source_2bit_file):
        export_2bit_file(args.hal_file, args.src_genome, source_2bit_file)

    destination_2bit_file = os.path.join(hal_aux_dir, f'{args.dest_genome}.2bit')
    if not os.path.isfile(destination_2bit_file):
        export_2bit_file(args.hal_file, args.dest_genome, destination_2bit_file)

    source_chr_sizes = load_chr_sizes(args.hal_file, args.src_genome)

    if args.src_region is not None:
        source_regions: Iterable = [SimpleRegion.from_1_based_region_string(args.src_region)]
    else:
        source_regions = read_region_tsv_file(args.src_region_tsv)

    if args.alt_synonym_json is not None:
        src_chr_to_alt, src_alt_to_chr, dest_alt_to_chr = load_liftover_alt_synonyms(args.alt_synonym_json,
                                                                                     args.src_genome,
                                                                                     args.dest_genome)
        source_regions = (
            SimpleRegion(src_chr_to_alt[x.chr], x.start, x.end, x.strand, validate=False)
            for x in source_regions
        )

    if args.cache_chain:

        if args.linear_gap not in ['medium', 'loose']:
            raise ValueError(f"chain caching not yet supported for linear-gap value: '{args.linear_gap}'")

        cached_chain_file = os.path.join(
            hal_aux_dir,
            f'{args.src_genome}_to_{args.dest_genome}.linearGap_{args.linear_gap}.chain'
        )
        if not os.path.isfile(cached_chain_file):
            destination_chr_sizes = load_chr_sizes(args.hal_file, args.dest_genome)
            make_chain_file(args.dest_genome, destination_2bit_file, destination_chr_sizes,
                            args.src_genome, source_2bit_file, args.hal_file, cached_chain_file,
                            linear_gap=args.linear_gap)

    records = []
    for source_region in source_regions:
        if args.cache_chain:
            record = liftover_via_chain(source_region, args.src_genome, source_chr_sizes, args.dest_genome,
                                        destination_2bit_file, cached_chain_file, flank_length=args.flank)
        else:
            record = liftover_via_hal(source_region, args.src_genome, source_2bit_file, source_chr_sizes,
                                       args.dest_genome, destination_2bit_file, args.hal_file,
                                       flank_length=args.flank, skip_chain=args.skip_chain,
                                       linear_gap=args.linear_gap)
        records.append(record)

    if args.alt_synonym_json is not None:
        for record in records:
            record['params']['src_chr'] = src_alt_to_chr[record['params']['src_chr']]
            for result in record['results']:
                result['dest_chr'] = dest_alt_to_chr[result['dest_chr']]
                if 'lifted_src_chr' in result:
                    result['lifted_src_chr'] = src_alt_to_chr[result['lifted_src_chr']]

    if args.output_format == 'JSON':

        with open(args.output_file, 'w') as file_obj:
            json.dump(records, file_obj)

    elif args.output_format == 'TSV':

        output_field_names = [
            'src_genome',
            'src_chr',
            'src_start',
            'src_end',
            'src_strand',
            'flank',
            'dest_genome',
            'lifted_src_chr',
            'lifted_src_start',
            'lifted_src_end',
            'lifted_src_strand',
            'dest_chr',
            'dest_start',
            'dest_end',
            'dest_strand',
            'dest_sequence'
        ]

        with open(args.output_file, 'w') as file_obj:
            writer = csv.DictWriter(file_obj, output_field_names, dialect=UnixTab)
            writer.writeheader()
            for record in records:
                params = record['params']
                for result in record['results']:
                    writer.writerow({**params, **result})
