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
      --keep-genomes-file genome_list.txt input.hal output.maf

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
    parser.add_argument('--keep-genomes-file', metavar='PATH', required=True,
                        help="File listing genomes to include in output alignments, one per line.")

    parser.add_argument('--min-block-seqs', metavar='INT', type=int, default=3,
                        help="Minimum number of sequences per block.")
    parser.add_argument('--min-block-size', metavar='INT', type=int, default=200,
                        help="Minimum number of columns per block.")
    args = parser.parse_args()

    with open(args.keep_genomes_file) as f:
        keep_genomes = [line.rstrip() for line in f]

    command = [
        'hal2maf',
         args.hal_file,
        'stdout',
        '--refGenome', args.ref_genome,
        '--refSequence', args.ref_sequence,
        '--targetGenomes', ','.join(keep_genomes)
    ]

    with open(args.maf_file, 'w') as out_f:
        out_f.write('##maf version=1 scoring=N/A\n\n')
        writer = MafWriter(out_f)

        with subprocess.Popen(command, stdout=subprocess.PIPE, text=True) as process:
            for msa in MafIterator(process.stdout):
                if len(msa) < args.min_block_seqs:
                    continue
                if msa.get_alignment_length() < args.min_block_size:
                    continue

                writer.write_alignment(msa)
