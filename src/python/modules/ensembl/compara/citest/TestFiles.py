# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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
"""Directory tree framework for the Continuous Integration Test (CITest) suite.

This module defines the required classes to load and test directory trees from different runs of the same
pipeline. The main class, TestFilesItem, has been designed and implemented to be used with ``pytest``.

"""

import copy
import filecmp
from functools import reduce
import operator
import os
from typing import Callable, Dict, List, Union

import pytest
from _pytest._code.code import ExceptionChainRepr, ExceptionInfo, ReprExceptionInfo
from _pytest.fixtures import FixtureLookupErrorRepr

from ensembl.compara.citest.CITest import CITestItem


class DirCmp:
    """Directory comparison object, to compare reference and target directory trees.

    Args:
        ref_path: Reference's root path, e.g. "/home/user/pipelines/reference".
        target_path: Target's root path, e.g. "/home/user/pipelines/target".

    Attributes:
        ref_path (str): Reference's root path.
        target_path (str): Target's root path.
        common_tree (dict): Directory tree shared between reference and target paths.

    Raises:
        AssertionError: If reference or target paths do not exist.

    """
    def __init__(self, ref_path: str, target_path: str):
        assert os.path.exists(ref_path), "Reference path '{}' not found".format(ref_path)
        assert os.path.exists(target_path), "Target path '{}' not found".format(target_path)
        # Get the directory trees for the given reference and target paths
        self.ref_path = os.path.abspath(ref_path)
        self._ref_tree_only = self._get_dir_tree(self.ref_path)
        if os.path.isfile(self.ref_path):
            self.ref_path = os.path.dirname(self.ref_path)
        self.target_path = os.path.abspath(target_path)
        self._target_tree_only = self._get_dir_tree(self.target_path)
        if os.path.isfile(self.target_path):
            self.target_path = os.path.dirname(self.target_path)
        self.common_tree = copy.deepcopy(self.get_ref_only())
        # Recursive nested function (closure) to compare reference and target trees and build the common one
        def cmp_trees(ref_node: Dict, target_node: Dict, common_node: Dict) -> None:
            """Compares reference and target trees, moving their shared structure to the common tree."""
            ref_dirnames = set(ref_node.keys())
            target_dirnames = set(target_node.keys())
            # Remove directories only found on the reference tree
            for dirname in ref_dirnames.difference(target_dirnames):
                del common_node[dirname]
            for dirname in common_node.keys():
                if dirname != '.':
                    cmp_trees(ref_node[dirname], target_node[dirname], common_node[dirname])
                else:
                    # Remove files only found on the reference tree
                    for filename in ref_node[dirname].difference(target_node[dirname]):
                        common_node[dirname].remove(filename)
                    # Remove common files from reference and target trees
                    for filename in common_node[dirname]:
                        ref_node[dirname].remove(filename)
                        target_node[dirname].remove(filename)
                # Remove emptied directories
                if not common_node[dirname]:
                    del common_node[dirname]
                if not ref_node[dirname]:
                    del ref_node[dirname]
                if not target_node[dirname]:
                    del target_node[dirname]
        # Compare the directory trees from their root
        cmp_trees(self._ref_tree_only, self._target_tree_only, self.common_tree)

    @staticmethod
    def _get_dir_tree(path: str) -> Dict:
        """Returns the directory tree rooted at the given path.

        Note:
            Files of each folder will be under the key ``.``.

        Args:
            path: Root path.

        """
        if os.path.isfile(path):
            tree_dict = {'.': set(os.path.basename(path))}  # type: Dict
        else:
            tree_dict = {'': {}}
            for dirpath, dirnames, filenames in os.walk(path):
                dirpath = dirpath.replace(path, '')
                subtree = reduce(operator.getitem, dirpath.split(os.sep), tree_dict)
                subtree.update({name: {} for name in dirnames})
                subtree['.'] = set(filenames)
            tree_dict = tree_dict['']
        return tree_dict

    @staticmethod
    def _prune_tree(root: Dict, paths: Union[str, List] = None, raise_err: bool = False) -> Dict:
        """Returns a pruned directory tree that only includes the given paths.

        Note:
            If `paths` is empty, it returns `root`.

        Args:
            root: Directory tree.
            paths: Relative directory path(s) to include.
            raise_err: Raise exception flag.

        Raises:
            ValueError: if `raise_err` is True and any relative path is not part of the directory tree.

        """
        if not paths:
            return root
        # Make sure paths is a list
        if isinstance(paths, str):
            paths = [paths]
        pruned_tree = {}  # type: Dict
        for rel_path in paths:
            # Normalize relative path to ensure reduce() finds it correctly
            dirnames = os.path.normpath(rel_path).split(os.path.sep)
            try:
                tree_node = reduce(operator.getitem, dirnames, root)
            except KeyError:
                if raise_err:
                    # Suppress exception context to display only the ValueError
                    raise ValueError("Path '{}' not found in the directory tree".format(rel_path)) from None
                continue
            # Create/find the path in the pruned tree and attach the subtree
            pruned_node = pruned_tree
            for name in dirnames[:-1]:
                pruned_node = pruned_node.setdefault(name, {})
            pruned_node[dirnames[-1]] = tree_node
        return pruned_tree

    @staticmethod
    def _eval_tree(root: Dict, test_func: Callable) -> List:
        """Returns the files in the directory tree for which the test function returns False.

        Args:
            test_func: Test function to apply to each file. It has to match the following interface::
                def test_func(file: str) -> bool:
                    ...

        """
        nodes_left = [('', root)]
        mismatches = []
        while nodes_left:
            rel_path, node = nodes_left.pop()
            for dirname, dir_content in node.items():
                if dirname != '.':
                    # Append dirname to the list of directories left to evaluate
                    nodes_left.append((os.path.join(rel_path, dirname), dir_content))
                else:
                    # Apply test_func() to each file
                    for filename in dir_content:
                        filepath = os.path.join(rel_path, filename)
                        if not test_func(filepath):
                            mismatches.append(filepath)
        return mismatches

    def get_ref_only(self, paths: Union[str, List] = None) -> Dict:
        """Returns the reference-only directory tree that only includes the given paths.

        Args:
            paths: Relative directory path(s) to include.

        """
        return self._prune_tree(self._ref_tree_only, paths)

    def get_target_only(self, paths: Union[str, List] = None) -> Dict:
        """Returns the target-only directory tree that only includes the given paths.

        Args:
            paths: Relative directory path(s) to include.

        """
        return self._prune_tree(self._target_tree_only, paths)

    def apply_test(self, test_func: Callable, paths: Union[str, List] = None) -> List:
        """Returns the files in the common directory tree for which the test function returns False.

        Args:
            test_func: Test function to apply to each file. It has to match the following interface::
                    def test_func(file: str) -> bool:
            paths: Relative directory path(s) to evaluate.

        """
        tree_to_traverse = self._prune_tree(self.common_tree, paths, True)
        return self._eval_tree(tree_to_traverse, test_func)

    def flatten(self, root: Dict, path: str = "") -> List:
        """Returns the flattened directory tree, i.e. list of file paths.

        Args:
            tree_root: Directory tree.
            path: Path to prepend to every file's relative path.

        """
        # Passing a function that always returns False makes _eval_tree() return a list containing every file
        # in the directory tree
        tree_files = self._eval_tree(root, lambda x: False)
        return [os.path.join(path, rel_path) for rel_path in tree_files]


class TestFilesItem(CITestItem):
    """Generic tests to compare two (analogous) Ensembl Compara files (or directories).

    Args:
        name: Name of the test to run.
        parent: The parent collector node.
        dir_cmp: Directory comparison object to run the test against.
        args: Arguments to pass to the test call.

    Attributes:
        dir_cmp (DirCmp): Directory comparison object to run the test against.

    """
    def __init__(self, name: str, parent: pytest.Item, dir_cmp: DirCmp, args: Dict) -> None:
        super().__init__(name, parent, args)
        self.dir_cmp = dir_cmp

    def repr_failure(self, excinfo: ExceptionInfo, style: str = None
                    ) -> Union[str, ReprExceptionInfo, ExceptionChainRepr, FixtureLookupErrorRepr]:
        """Returns the failure representation that will be displayed in the report section.

        Note:
            This method is called when ``self.runtest()`` raises an exception.

        Args:
            excinfo: Exception information with additional support for navigating and traceback.
            style: Traceback print mode (``auto``/``long``/``short``/``line``/``native``/``no``).

        """
        if isinstance(excinfo.value, TestFilesException):
            self.error_info['reference_only'] = excinfo.value.args[0]
            self.error_info['target_only'] = excinfo.value.args[1]
            self.error_info['mismatches'] = excinfo.value.args[2]
            if excinfo.value.args[3]:
                return excinfo.value.args[3] + "\n"
            return "Reference and target directory trees are not the same\n"
        return super().repr_failure(excinfo, style)

    def get_report_header(self) -> str:
        """Returns the header to display in the error report."""
        return "File test: {}".format(self.name)

    def test_size(self, variation: float = 0.0, paths: Union[str, List] = None) -> None:
        """Compares the size (in bytes) between reference and target files.

        Only the selected relative directory paths (and their subdirectories) will be compared.

        Args:
            variation: Allowed size variation between reference and target files.
            paths: Relative directory path(s) to be compared.

        Raises:
            TestFilesException: If at least one file differ in size between reference and target; or if
                reference and target directory trees differ (for any selected path).
            ValueError: If at least one selected path is not part of the common directory tree.

        """
        # Nested function (closure) to compare the reference and target file sizes
        def cmp_file_size(filepath: str) -> bool:
            """Returns True if target file size is within the allowed variation, False otherwise."""
            ref_size = os.path.getsize(os.path.join(self.dir_cmp.ref_path, filepath))
            target_size = os.path.getsize(os.path.join(self.dir_cmp.target_path, filepath))
            return abs(ref_size - target_size) <= (ref_size * variation)
        # Traverse the common directory tree, comparing every reference and target file sizes
        mismatches = self.dir_cmp.apply_test(cmp_file_size, paths)
        # Load the lists of files either in the reference or the target (but not in both)
        ref_only = self.dir_cmp.flatten(self.dir_cmp.get_ref_only(paths))
        target_only = self.dir_cmp.flatten(self.dir_cmp.get_target_only(paths))
        if mismatches:
            message = "{} file{} differ in size more than the allowed variation ({})".format(
                len(mismatches), 's' if len(mismatches) > 1 else '', variation)
            raise TestFilesException(ref_only, target_only, mismatches, message)
        elif ref_only or target_only:
            raise TestFilesException(ref_only, target_only, mismatches, '')

    def test_content(self, paths: Union[str, List] = None) -> None:
        """Compares the content (byte-by-byte) between reference and target files.

        Only the selected relative directory paths (and their subdirectories) will be compared.

        Args:
            paths: Relative directory path(s) to be compared.

        Raises:
            TestFilesException: If at least one file differ between reference and target; or if reference and
                target directory trees differ (for any selected path).
            ValueError: If at least one selected path is not part of the common directory tree.

        """
        # Nested function (closure) to compare the reference and target files
        def cmp_file_content(filepath: str) -> bool:
            """Returns True if reference and target files are equal, False otherwise."""
            ref_filepath = os.path.join(self.dir_cmp.ref_path, filepath)
            target_filepath = os.path.join(self.dir_cmp.target_path, filepath)
            return filecmp.cmp(ref_filepath, target_filepath)
        # Traverse the common directory tree, comparing every reference and target files
        mismatches = self.dir_cmp.apply_test(cmp_file_content, paths)
        # Load the lists of files either in the reference or the target (but not in both)
        ref_only = self.dir_cmp.flatten(self.dir_cmp.get_ref_only(paths))
        target_only = self.dir_cmp.flatten(self.dir_cmp.get_target_only(paths))
        if mismatches:
            message = "Found {} file{} with different content".format(len(mismatches),
                                                                      's' if len(mismatches) > 1 else '')
            raise TestFilesException(ref_only, target_only, mismatches, message)
        elif ref_only or target_only:
            raise TestFilesException(ref_only, target_only, mismatches, '')


class TestFilesException(Exception):
    """Exception subclass created to handle test failures separatedly from unexpected exceptions."""
