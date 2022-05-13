#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
See the NOTICE file distributed with this work for additional information
regarding copyright ownership.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

import argparse
from Bio import SeqIO

# Parse command line arguments:
parser = argparse.ArgumentParser(
    description='Filter for longest BUSCO isoform.')
parser.add_argument(
    '-i', metavar='input', type=str, help="Input.")
parser.add_argument(
    '-o', metavar='output', type=str, help="Output.", default="filtered_busco.fas")
parser.add_argument(
    '-l', metavar='output', type=str, help="List of BUSCO genes.", default="busco_genes.tsv")

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

    with open(args.o, "w") as output_handle:
        SeqIO.write(db.values(), output_handle, "fasta")

    with open(args.l, "w") as oh:
        oh.write("Gene\n")
        for gene in db.keys():
            oh.write(f"{gene}\n")
