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
"""File comparison methods for different file formats.

This module provides a main file comparison method, :meth:`file_cmp()`, that compares two files and returns
True if they are equivalent, False otherwise. The comparison is made differently depending on the file format.
For instance, two Newick files are considered equal if one tree is the result of a permutation of the other.

Typical usage examples::

    file_cmp('a/homo_sapiens.fa', 'b/homo_sapiens.fa')

    from pathlib import Path
    file_cmp(Path('a', 'tree1.nw'), Path('b', 'tree2.nw'))

"""

__all__ = ['NEWICK_EXT', 'file_cmp']

import filecmp
from pathlib import Path

from Bio import Phylo

from .dircmp import PathLike


# File extensions that should be interpreted as the same file format:
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
        return _tree_cmp(fpath1, fpath2)
    # Resort to a shallow binary file comparison (files with identical os.stat() signatures are taken to be
    # equal)
    return filecmp.cmp(str(fpath1), str(fpath2))


def _tree_cmp(fpath1: PathLike, fpath2: PathLike, tree_format: str = 'newick') -> bool:
    """Returns True if trees stored in `fpath1` and `fpath2` are equivalent, False otherwise.

    Args:
        fpath1: First tree file path.
        fpath2: Second tree file path.
        tree_format: Tree format, i.e. ``newick``, ``nexus``, ``phyloxml`` or ``nexml``.

    """
    ref_tree = Phylo.read(fpath1, tree_format)
    target_tree = Phylo.read(fpath2, tree_format)
    # Both trees are considered equal if they have the same leaves and the same distance from each to the root
    ref_dists = {leaf.name: ref_tree.distance(leaf) for leaf in ref_tree.get_terminals()}
    target_dists = {leaf.name: target_tree.distance(leaf) for leaf in target_tree.get_terminals()}
    return ref_dists == target_dists
