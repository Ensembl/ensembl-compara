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
"""
Script for filtering for the longest protein isoform per gene.

Example:
    $ python filter_for_longest_busco.py -i input.fas -o output.fas -l output.genes.tsv
"""
import sys
import argparse
import re
from Bio import SeqIO

# Parse command line arguments:
parser = argparse.ArgumentParser(
    description='Filter for longest BUSCO isoform.')
parser.add_argument(
    '-i', metavar='input', type=str, help="Input fasta.", required=True)
parser.add_argument(
    '-o', metavar='output', type=str, help="Output fasta.",
    default="filtered_busco.fas", required=True)
parser.add_argument(
    '-l', metavar='output', type=str, help="List of BUSCO genes.",
    required=True)
parser.add_argument(
    '-r', metavar='rep_filter', type=int,
    help="Filter out seqeunces with repeats longer than this.",
    required=False, default=None)
parser.add_argument(
    '-f', metavar='rep_out', type=str, help="Fasta of filtered out sequences.",
    default="repetitive_busco.fas", required=False)


if __name__ == '__main__':
    args = parser.parse_args()

    db = {}
    with open(args.i) as handle:
        for record in SeqIO.parse(handle, "fasta"):
            gene = record.id.split("_")[0]
            if gene not in db:
                db[gene] = record
            elif len(record.seq) > len(db[gene].seq):
                db[gene] = record

    if len(db) == 0:
        sys.stderr.write("Empty BUSCO gene set!\n")
        sys.exit(1)

    i = 0
    repetitive = {}
    for k, v in list(db.items()):
        seq = str(v.seq)
        if args.r is not None:
            rg = f"([A-Za-z]+?)\\1{{{args.r},}}"
            res = re.search(rg, seq)
            if res:
                repetitive[k] = v
                del db[k]
            else:
                v.id = f"g{i}"
                v.description = ""
                i += 1

    with open(args.o, "w") as output_handle:
        SeqIO.write(db.values(), output_handle, "fasta")

    with open(args.f, "w") as output_handle:
        SeqIO.write(repetitive.values(), output_handle, "fasta")

    with open(args.l, "w") as oh:
        oh.write("Gene\tGeneId\n")
        for gene, rec in db.items():
            gid = rec.id
            oh.write(f"{gene}\t{gid}\n")
