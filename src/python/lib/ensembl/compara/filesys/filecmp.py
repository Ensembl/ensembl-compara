"""
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

import filecmp
from pathlib import Path

from ete3 import Tree

from .dircmp import PathLike


# Set of file extensions that should be interpreted as a Newick file format
NEWICK_EXT = {'.nw', '.nwk', '.newick', '.nh'}


def file_cmp(fpath1: PathLike, fpath2: PathLike) -> bool:
    """Returns True if files `fpath1` and `fpath2` are equivalent, False otherwise.

    Args:
        fpath1: First file path.
        fpath2: Second file path.

    """
    fext1 = Path(fpath1).suffix
    fext2 = Path(fpath2).suffix
    if (fext1 in NEWICK_EXT) and (fext2 in NEWICK_EXT):
        return _newick_cmp(fpath1, fpath2)
    # Resort to a shallow binary file comparison (files with identical os.stat() signatures are taken to be
    # equal)
    return filecmp.cmp(str(fpath1), str(fpath2))


def _newick_cmp(fpath1: PathLike, fpath2: PathLike) -> bool:
    """Returns True if the trees stored in `fpath1` and `fpath2` are equivalent, False otherwise.

    Args:
        fpath1: First file path.
        fpath2: Second file path.

    """
    ref_tree = Tree(fpath1, format=5)
    target_tree = Tree(fpath2, format=5)
    # Check the leaves all match
    ref_leaves = set(ref_tree.get_leaf_names())
    target_leaves = set(target_tree.get_leaf_names())
    if ref_leaves != target_leaves:
        return False
    # Check the distance to the root for each leaf
    for leaf in ref_leaves:
        if leaf.get_distance(ref_tree) != leaf.get_distance(target_tree):
            return False
    return True
