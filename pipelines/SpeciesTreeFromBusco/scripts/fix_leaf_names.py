#!/usr/bin/env python3

# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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

"""
Replace leaf names in a species tree with production name.
Example:
    $ python fix_leaf_names.py -t astral_species_tree_neutral_bl.nwk -c input_genomes.csv -o test.nwk
"""

import sys
import argparse
from os import path
from Bio import Phylo
import pandas as pd

# Parse command line arguments:
parser = argparse.ArgumentParser(
    description='Replace leafs of a species tree with production names.')
parser.add_argument(
    '-t', metavar='tree', type=str, help="Input tree.", required=True, default=None)
parser.add_argument(
    '-c', metavar='csv', type=str, help="Input CSV.", required=True, default=None)
parser.add_argument(
    '-o', metavar='output', type=str, help="Output tree.", required=True)


if __name__ == '__main__':
    args = parser.parse_args()

    df = pd.read_csv(args.c, delimiter="\t", header=None)
    trans_map = {}
    for r in df.itertuples():
        trans_map[r[10]] = r[2]

    tree = Phylo.read(args.t, format="newick")
    for leaf in tree.get_terminals():
        leaf.name = trans_map[leaf.name]

    Phylo.write(
        trees=tree,
        file=args.o,
        format="newick"
    )
