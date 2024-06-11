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
Pick out every third site from a codon alignment. The input sequences
must have a length divisible by 3.

Example:
    $ python  pick_third_site.py -i input.fas -o output.fas
"""

import sys
import argparse
from collections import OrderedDict

import pandas as pd
from Bio import SeqIO

# Parse command line arguments:
parser = argparse.ArgumentParser(
    description='Pick out the third sites from a codon alignment.')
parser.add_argument(
    '-i', metavar='input', type=str, help="Input fasta.", required=True)
parser.add_argument(
    '-o', metavar='output', type=str, help="Output fasta.", required=True)


if __name__ == '__main__':
    args = parser.parse_args()

    fh = open(args.o, "w")

    for record in SeqIO.parse(args.i, "fasta"):
        # Check if sequence length is divisible by 3:
        if len(record.seq) % 3 != 0:
            sys.stderr.write(f"The length of sequence {record.id} is not divisible by 3!\n")
            sys.exit(1)
        # Pick out every third site:
        print(len(record.seq))
        record.seq = record.seq[2::3]
        # Write out record:
        SeqIO.write(record, fh, "fasta")

    fh.flush()
    fh.close()
