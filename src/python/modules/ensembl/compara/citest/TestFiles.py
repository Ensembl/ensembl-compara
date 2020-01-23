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
"""Module docstring"""
# TODO: write module docstring

from collections import OrderedDict
from functools import reduce
import operator
import os
from typing import Dict, List, Union

import numpy
import pandas
import pytest
from _pytest.fixtures import FixtureRequest


pandas.set_option('max_colwidth', 100)


class TestFilesException(Exception):
    """Exception subclass created to handle test failures separatedly from unexpected exceptions."""
    pass


# Hide the exception traceback only for those exceptions raised intentionally due to a failed test
__tracebackhide__ = operator.methodcaller("errisinstance", TestFilesException)


class TestFiles:
    """Generic tests to compare two (analogous) Ensembl Compara files or directories.

    Args:
        ref_path: Absolute path to reference's root directory, e.g.
            "/hps/nobackup2/production/ensembl/user/ref_pipeline".
        target_path: Absolute path to target's root directory, e.g.
            "/hps/nobackup2/production/ensembl/user/target_pipeline".

    Attributes:
        ref_path (str): Absolute path to reference's root directory.
        ref_tree (dict): Reference's root directory tree.
        target_path (str): Absolute path to target's root directory.
        target_tree (dict): Target's root directory tree.

    Raises:
        AssertionError: If the given paths are not absolute or they don't exist.
    """
    def __init__(self, ref_path: str, target_path: str):
        assert os.path.isabs(ref_path), "'{}' is not an absolute path".format(ref_path)
        assert os.path.isdir(ref_path), "Invalid reference directory '{}'".format(ref_path)
        assert os.path.isabs(target_path), "'{}' is not an absolute path".format(target_path)
        assert os.path.isdir(target_path), "Invalid target directory '{}'".format(target_path)
        self.ref_path = ref_path.rstrip(os.path.sep)
        self.ref_tree = self._get_dir_tree(ref_path)
        self.target_path = target_path.rstrip(os.path.sep)
        self.target_tree = self._get_dir_tree(target_path)

    def test_size(self, request: FixtureRequest, variation: float = 0.0, paths: Union[str, List] = None
                 ) -> None:
        """Compares the size (in bytes) between reference and target files.

        The test will compare the whole directory tree for each given directory. The test will fail if there
        are differences between the reference and target directory trees (for the selected paths). If none of
        the selected relative paths are part of the common directory tree, the test will pass sucessfully.

        Note:
            The ceiling function is applied to round the allowed variation in order to compare two integers.
            Thus, the test may pass even if the size difference between two files is greater than the exact
            allowed variation, e.g. size difference is 2 and the allowed variation is 1,4.

        Args:
            request: Special fixture providing information of the requesting test function.
            variation: Allowed size variation between reference and target files.
            paths: Compare only this(these) directory relative path(s).

        Raises:
            TestFilesException: If at least one file differ in size between reference and target; or if
                reference and target directory trees differ.
        """
        if (paths is None) or isinstance(paths, str):
            paths = [paths] if paths else []
        report = {
            "ref_only": [],
            "target_only": [],
            "mismatches": pandas.DataFrame(columns=["file", "expected", "found"])
        }
        # Start from the root of the directory trees
        to_explore = [("", self.ref_tree, self.target_tree)]
        while to_explore:
            rel_path, ref_node, target_node = to_explore.pop(0)
            ref_dirnames = set(ref_node.keys())
            target_dirnames = set(target_node.keys())
            # Report those directories only found either on the reference or the target
            if not paths or (rel_path in paths):
                for dirname in ref_dirnames.difference(target_dirnames):
                    report["ref_only"].append(os.path.join(rel_path, dirname, "*"))
                for dirname in target_dirnames.difference(ref_dirnames):
                    report["target_only"].append(os.path.join(rel_path, dirname, "*"))
            for dirname in ref_dirnames.intersection(target_dirnames):
                if dirname != ".":
                    # Append dirname to relative path and add it to the list of dirpaths to explore
                    to_explore.append((os.path.join(rel_path, dirname), ref_node[dirname],
                                       target_node[dirname]))
                elif not paths or (rel_path in paths):
                    ref_filepaths = set(os.path.join(rel_path, filename) for filename in ref_node[dirname])
                    target_filepaths = set(os.path.join(rel_path, filename)
                                           for filename in target_node[dirname])
                    # Report those files only found either on the reference or the target
                    for filepath in ref_filepaths.difference(target_filepaths):
                        report["ref_only"].append(filepath)
                    for filepath in target_filepaths.difference(ref_filepaths):
                        report["target_only"].append(filepath)
                    # Check if the size of the common files is within the allowed variation
                    for filepath in ref_filepaths.intersection(target_filepaths):
                        ref_size = os.path.getsize(os.path.join(self.ref_path, filepath))
                        target_size = os.path.getsize(os.path.join(self.target_path, filepath))
                        if abs(ref_size - target_size) > numpy.ceil(ref_size * variation):
                            report["mismatches"] = report["mismatches"].append(
                                dict(zip(report["mismatches"].columns, [filepath, ref_size, target_size])),
                                ignore_index=True
                            )
        if report["ref_only"] or report["target_only"] or not report["mismatches"].empty:
            if report["mismatches"].empty:
                mismatches = [] # type: List
                error_message = "Reference and target directory trees are not the same"
            else:
                # Save the error information in a readable format
                mismatches = report["mismatches"].to_string(index=False).splitlines()
                error_message = "{} file(s) differ in size more than the allowed variation ({})".format(
                    report["mismatches"].shape[0], variation)
            request.node.error_info = OrderedDict([
                ("reference_only", report["ref_only"]),
                ("target_only", report["target_only"]),
                ("mismatches", mismatches)
            ])
            raise TestFilesException(error_message)

    def test_content(self, request: FixtureRequest, paths: Union[str, List] = "") -> None:
        """Text

        Args:
            request: Special fixture providing information of the requesting test function.
        """
        pass

    @staticmethod
    def _eq_timestamp(ref_filename: str, target_filename: str) -> bool:
        """Text

        Args:

        Returns:
            True if both files have the same timestamp, False otherwise.
        """
        return os.path.getmtime(ref_filename) == os.path.getmtime(target_filename)

    @staticmethod
    def _get_dir_tree(src_path: str) -> Dict:
        """Returns the directory tree rooted at the source path.

        Args:
            src_path: Root path.

        Returns:
            Dictionary containing the directory tree rooted at src_path. The files of each folder will be
            under the key ".".
        """
        tree_dict = {"": {}} # type: Dict
        for dirpath, dirnames, filenames in os.walk(src_path):
            dirpath = dirpath.replace(src_path, "")
            subtree = reduce(operator.getitem, dirpath.split(os.path.sep), tree_dict)
            subtree.update({name: {} for name in dirnames})
            subtree["."] = set(filenames)
        tree_dict = tree_dict[""]
        return tree_dict
