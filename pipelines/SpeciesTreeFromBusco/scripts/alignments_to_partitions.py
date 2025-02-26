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
Merge alignments into partitions.

Example:
    $ python alignments_to_partitions.py -i input.fofn -o output.fas -p output_partitions.csv -t input.taxa
"""

import sys
import os
import argparse
from collections import OrderedDict

import pandas as pd
from Bio import SeqIO

# Parse command line arguments:
parser = argparse.ArgumentParser(
    description='Merge alignments with common (possibly partial) taxa.')
parser.add_argument(
    '-i', metavar='input', type=str, help="Input fofn.", required=True)
parser.add_argument(
    '-o', metavar='output', type=str, help="Output fasta.", required=True)
parser.add_argument(
    '-p', metavar='output', type=str, help="Partition file.", required=True)
parser.add_argument(
    '-t', metavar='input_list', type=str, help="Input taxa file.", required=True)


if __name__ == '__main__':
    args = parser.parse_args()

    # Read in taxa:
    taxa_df = pd.read_csv(args.t, sep="\t")
    taxa = sorted(taxa_df.Taxa)

    # Initialize results dict:
    merged = OrderedDict()
    for t in taxa:
        merged[t] = ""

    # Open partitions file:
    #  pylint: disable=consider-using-with
    part_fh = open(args.p, "w")

    # Slurp list of input alignemnts:
    with open(args.i) as x:
        aln_files = [y.strip() for y in x.readlines()]

    if len(aln_files) == 0:
        sys.stderr.write("No alignment files specified in the input fofn file!\n")
        sys.exit(1)

    # Total alignment length so far:
    total_len = 0
    # For each alignment:
    for nr_part, aln_file in enumerate(aln_files):
        # Check for empty alignments:
        if os.stat(aln_file).st_size == 0:
            continue
        # Read in aligned sequences:
        records = {x.id: x for x in SeqIO.parse(aln_file, "fasta")}
        # Get current lenght:
        curr_len = len(list(records.values())[0].seq)

        # Define partition start and end:
        start = total_len + 1
        end = total_len + curr_len

        # Define partition number:
        shift_part = nr_part + 1
        # Write out partition:
        part_fh.write(f"LG+F+G, part{shift_part} = {start}-{end}\n")
        # Advance length counter:
        total_len += curr_len
        # For each taxa concatenate the sequence if present, gaps if missing:
        for t in taxa:
            if t in records:
                merged[t] = merged[t] + str(records[t].seq)
            else:
                merged[t] = merged[t] + "-" * curr_len

    part_fh.flush()
    part_fh.close()

    # Write out merged alignment file:
    with open(args.o, "w") as fas_fh:
        for taxa, seq in merged.items():
            if seq.count("-") < len(seq):
                fas_fh.write(f">{taxa}\n{seq}\n")
