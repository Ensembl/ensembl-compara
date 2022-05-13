#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse
from Bio import SeqIO
from collections import defaultdict

# Parse command line arguments:
parser = argparse.ArgumentParser(
    description='Filter for longest BUSCO isoform.')
parser.add_argument(
    '-i', metavar='input', type=str, help="Input.")
parser.add_argument(
    '-o', metavar='output', type=str, help="Output.", default="filtered_busco.fas")


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
