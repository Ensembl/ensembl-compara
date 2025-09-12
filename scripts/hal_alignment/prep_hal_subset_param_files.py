#!/usr/bin/env python3
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Prepare parameter files for a HAL subsetting process."""

import argparse
from pathlib import Path
import subprocess
from typing import Union

from ete3 import Tree


def load_hal_newick(hal_file: Union[Path, str]) -> str:
    """Load Newick string from input HAL file.

    Args:
        hal_file: Input HAL file.

    Returns:
        Newick string of HAL tree.
    """
    cmd_args = ["halStats", "--tree", hal_file]
    process = subprocess.run(cmd_args, check=True, capture_output=True, text=True, encoding="ascii")
    return process.stdout.rstrip("\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--input-hal-file",
        required=True,
        help="Input HAL file which is to be subsetted.",
    )
    parser.add_argument(
        "--keep-genomes-file",
        required=True,
        help="Input file listing leaf genomes (one per line)"
        " which are to be kept in the subsetted HAL file.",
    )
    parser.add_argument(
        "--subtree-root-file",
        required=True,
        help="Output file containing the name of the genome "
        " which will be the root of the tree in the subsetted HAL file.",
    )
    parser.add_argument(
        "--drop-genomes-file",
        required=True,
        help="Output file listing genomes (one per line) in the order in"
        " which they will be removed from the HAL file being subsetted.",
    )

    args = parser.parse_args()

    hal_tree_newick = load_hal_newick(args.input_hal_file)
    hal_tree = Tree(hal_tree_newick, format=1)

    with open(args.keep_genomes_file) as in_file_obj:
        genomes_to_keep = set(line.rstrip("\n") for line in in_file_obj)

    # We will use halExtract on the subtree rooted at the common
    # ancestor of the genomes being kept in the subset HAL file.
    subtree_root = hal_tree.get_common_ancestor(*genomes_to_keep)
    subtree_root.detach()

    nodes_to_keep = set()
    for leaf in subtree_root.get_leaves():
        if leaf.name in genomes_to_keep:
            for node in leaf.get_ancestors():
                nodes_to_keep.add(node)
            nodes_to_keep.add(leaf)

    # Since halRemoveGenome can only be used to remove a
    # leaf genome, we start with the leaves and move towards
    # the root, adding genomes to the drop list as we go.
    genomes_to_drop = []
    for node in subtree_root.traverse("postorder"):
        if node not in nodes_to_keep:
            genomes_to_drop.append(node.name)

    with open(args.subtree_root_file, mode="w") as out_file_obj:
        print(subtree_root.name, file=out_file_obj)

    with open(args.drop_genomes_file, mode="w") as out_file_obj:
        for genome_name in genomes_to_drop:
            print(genome_name, file=out_file_obj)
