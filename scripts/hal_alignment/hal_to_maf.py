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

"""Extract a MAF alignment from a HAL file.

Examples::
    # Extract a MAF alignment with chromosome 19 of GRCh38 as reference.
    python hal_to_maf.py --ref-genome GRCh38 --ref-sequence chr19 \
      --genomes-file genome_list.txt input.hal output.maf

"""

from argparse import ArgumentParser
import subprocess

from Bio.AlignIO.MafIO import MafIterator, MafWriter


if __name__ == '__main__':

    parser = ArgumentParser(description='Extract a MAF alignment from a HAL file.')
    parser.add_argument('hal_file', help="Input HAL file.")
    parser.add_argument('maf_file', help="Output MAF file.")

    parser.add_argument('--ref-genome', metavar='STR', required=True,
                        help="Reference genome for output MAF file.")
    parser.add_argument('--ref-sequence', metavar='STR', required=True,
                        help="Output sequence within reference genome.")
    parser.add_argument('--genomes-file', metavar='PATH', required=True,
                        help="File listing genomes to include in output alignments, one per line.")

    parser.add_argument('--min-block-seqs', metavar='INT', type=int, default=3,
                        help="Minimum number of sequences per block.")
    parser.add_argument('--min-block-length', metavar='INT', type=int, default=200,
                        help="Minimum number of columns per block.")
    parser.add_argument('--max-block-length', metavar='INT', type=int,
                        help="Maximum number of columns per block.")
    parser.add_argument('--max-ref-gap', metavar='INT', type=int,
                        help="Maximum reference sequence gap length.")
    args = parser.parse_args()

    with open(args.genomes_file) as f:
        target_genomes = [line.rstrip() for line in f]

    # Ensembl defaults
    if len(target_genomes) > 1:
        default_max_block_length = 1_000_000
        default_max_ref_gap = 500
    else:
        default_max_block_length = 500_000
        default_max_ref_gap = 50

    if args.max_block_length is not None:
        max_block_length = args.max_block_length
    else:
        max_block_length = default_max_block_length

    if args.max_ref_gap is not None:
        max_ref_gap = args.max_ref_gap
    else:
        max_ref_gap = default_max_ref_gap

    command = [
        'hal2maf',
         args.hal_file,
        'stdout',
        '--refGenome', args.ref_genome,
        '--refSequence', args.ref_sequence,
        '--targetGenomes', ','.join(target_genomes),
        '--maxBlockLen', str(args.max_block_length),
        '--maxRefGap', str(args.max_ref_gap)
    ]

    with open(args.maf_file, 'w') as out_f:
        out_f.write('##maf version=1 scoring=N/A\n\n')
        writer = MafWriter(out_f)

        with subprocess.Popen(command, stdout=subprocess.PIPE, text=True) as process:
            for msa in MafIterator(process.stdout):
                if len(msa) < args.min_block_seqs:
                    continue
                if msa.get_alignment_length() < args.min_block_length:
                    continue

                writer.write_alignment(msa)
