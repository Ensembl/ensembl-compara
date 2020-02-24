"""
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

from collections import deque
from functools import reduce
from itertools import filterfalse
import os
from pathlib import Path
from typing import Callable, Deque, Dict, Iterator, List, Tuple, TypeVar


# Create the PathLike type as an alias for supported types a path can be stored into
PathLike = TypeVar('PathLike', str, os.PathLike)


class DirCmp:
    """Directory comparison object to compare reference and target directory trees.

    Args:
        ref_path: Reference's root path, e.g. ``/home/user/pipelines/reference``.
        target_path: Target's root path, e.g. ``/home/user/pipelines/target``.

    Attributes:
        ref_path (Path): Reference's directory path.
        target_path (Path): Target's directory path.
        common_files (Set[str]): Files shared between reference and target directories.
        ref_only (Set[str]): Files/subdirectories only found in the reference directory.
        target_only (Set[str]): Files/subdirectories only found in the target directory.
        subdirs (Dict[Path, DirCmp]): Shared subdirectories between reference and target directories.

    """
    def __init__(self, ref_path: PathLike, target_path: PathLike) -> None:
        self.ref_path = Path(ref_path)
        ref_dirnames, ref_filenames = next(os.walk(self.ref_path))[1:]
        ref_dnames = set(ref_dirnames)
        ref_fnames = set(ref_filenames)
        self.target_path = Path(target_path)
        target_dirnames, target_filenames = next(os.walk(self.target_path))[1:]
        target_dnames = set(target_dirnames)
        target_fnames = set(target_filenames)
        self.common_files = ref_fnames & target_fnames
        # Get files/subdirectories only present in the reference directory
        self.ref_only = ref_fnames - target_fnames
        self.ref_only |= set(map(lambda x: os.path.join(x, '*'), ref_dnames - target_dnames))
        # Get files/subdirectories only present in the target directory
        self.target_only = target_fnames - ref_fnames
        self.target_only |= set(map(lambda x: os.path.join(x, '*'), target_dnames - ref_dnames))
        self.subdirs = {}  # type: Dict[Path, DirCmp]
        for dirname in ref_dnames & target_dnames:
            self.subdirs[Path(dirname)] = DirCmp(self.ref_path / dirname, self.target_path / dirname)

    def _traverse(self, attr: str, *paths: PathLike) -> Iterator[str]:
        """Yields each element of the requested attribute found in the directory tree(s).

        This method traverses the shared directory tree in breadth-first order.

        Args:
            attr: Attribute to return, i.e. ``common_files``, ``ref_only`` or ```target_only``.
            *paths: Relative directory paths to traverse.

        Raises:
            ValueError: If one of `paths` is not part of the shared directory tree.

        """
        nodes_left = deque()  # type: Deque[Tuple[Path, DirCmp]]
        # Fetch and append the root node of each relative path
        for rel_path in paths:
            try:
                node = reduce(lambda x, y: x.subdirs[Path(y)], Path(rel_path).parts, self)
            except KeyError:
                # Suppress exception context to display only the ValueError
                raise ValueError(f"Path '{rel_path}' not found in shared directory tree") from None
            nodes_left.append((Path(rel_path), node))
        # If no nodes were added, add the root as the starting point
        if not nodes_left:
            nodes_left.append((Path(), self))
        while nodes_left:
            dirname, node = nodes_left.pop()
            # Append subdirectories to the list of directories left to traverse
            nodes_left.extend([(dirname / subdir, subnode) for subdir, subnode in node.subdirs.items()])
            for file in getattr(node, attr):
                yield str(dirname / file)

    def apply_test(self, test_func: Callable, *paths: PathLike) -> List[str]:
        """Returns the files in the shared directory tree for which the test function returns False.

        Args:
            test_func: Test function to apply to each file. It has to match the following interface::

                def test_func(file: PathLike) -> bool:
                    ...

            *paths: Relative directory paths to evaluate.

        """
        return list(filterfalse(test_func, self._traverse('common_files', *paths)))

    def common_list(self, *paths: PathLike) -> List[str]:
        """Returns the files/directories found in the shared directory tree.

        Args:
            *paths: Relative directory paths to return.

        """
        return list(self._traverse('common_files', *paths))

    def ref_only_list(self, *paths: PathLike) -> List[str]:
        """Returns the files/directories only found in the reference directory tree.

        Args:
            *paths: Relative directory paths to return.

        """
        return list(self._traverse('ref_only', *paths))

    def target_only_list(self, *paths: PathLike) -> List[str]:
        """Returns the files/directories only found in the target directory tree.

        Args:
            *paths: Relative directory paths to return.

        """
        return list(self._traverse('target_only', *paths))
