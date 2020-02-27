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
import os
from typing import Dict, List, Union

import pytest
from _pytest._code.code import ExceptionChainRepr, ExceptionInfo, ReprExceptionInfo
from _pytest.fixtures import FixtureLookupErrorRepr

from ..utils import DirCmp, PathLike, to_list
from ._citest import CITestItem


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
        if isinstance(excinfo.value, FailedFilesTestException):
            self.error_info['reference_only'] = excinfo.value.args[0]
            self.error_info['target_only'] = excinfo.value.args[1]
            self.error_info['mismatches'] = excinfo.value.args[2]
            if excinfo.value.args[3]:
                return excinfo.value.args[3] + "\n"
            return "Reference and target directory trees are not the same\n"
        return super().repr_failure(excinfo, style)

    def get_report_header(self) -> str:
        """Returns the header to display in the error report."""
        return f"File test: {self.name}"

    def test_size(self, variation: float = 0.0, paths: Union[PathLike, List] = None) -> None:
        """Compares the size (in bytes) between reference and target files.

        Only the selected relative directory paths (and their subdirectories) will be compared.

        Args:
            variation: Allowed size variation between reference and target files.
            paths: Relative directory path(s) to be compared.

        Raises:
            FailedFilesTestException: If at least one file differ in size between reference and target; or if
                reference and target directory trees differ (for any selected path).
            ValueError: If at least one selected path is not part of the common directory tree.

        """
        paths = to_list(paths)
        # Nested function (closure) to compare the reference and target file sizes
        def cmp_file_size(filepath: PathLike) -> bool:
            """Returns True if target file size is larger than the allowed variation, False otherwise."""
            ref_size = os.path.getsize(self.dir_cmp.ref_path / filepath)
            target_size = os.path.getsize(self.dir_cmp.target_path / filepath)
            return abs(ref_size - target_size) > (ref_size * variation)
        # Traverse the common directory tree, comparing every reference and target file sizes
        mismatches = self.dir_cmp.apply_test(cmp_file_size, *paths)
        # Load the lists of files either in the reference or the target (but not in both)
        ref_only = self.dir_cmp.ref_only_list(*paths)
        target_only = self.dir_cmp.target_only_list(*paths)
        if mismatches:
            num_mms = len(mismatches)
            message = (
                f"{num_mms} file{'s' if num_mms > 1 else ''} differ in size more than the allowed variation "
                f"({variation})"
            )
            raise FailedFilesTestException(ref_only, target_only, mismatches, message)
        if ref_only or target_only:
            raise FailedFilesTestException(ref_only, target_only, mismatches, '')

    def test_content(self, paths: Union[PathLike, List] = None) -> None:
        """Compares the content (byte-by-byte) between reference and target files.

        Only the selected relative directory paths (and their subdirectories) will be compared.

        Args:
            paths: Relative directory path(s) to be compared.

        Raises:
            FailedFilesTestException: If at least one file differ between reference and target; or if
                reference and target directory trees differ (for any selected path).
            ValueError: If at least one selected path is not part of the common directory tree.

        """
        paths = to_list(paths)
        # Nested function (closure) to compare the reference and target files
        def cmp_file_content(filepath: PathLike) -> bool:
            """Returns True if reference and target files differ, False otherwise."""
            ref_filepath = str(self.dir_cmp.ref_path / filepath)
            target_filepath = str(self.dir_cmp.target_path / filepath)
            return not filecmp.cmp(ref_filepath, target_filepath)
        # Traverse the common directory tree, comparing every reference and target files
        mismatches = self.dir_cmp.apply_test(cmp_file_content, *paths)
        # Load the lists of files either in the reference or the target (but not in both)
        ref_only = self.dir_cmp.ref_only_list(*paths)
        target_only = self.dir_cmp.target_only_list(*paths)
        if mismatches:
            num_mms = len(mismatches)
            message = f"Found {num_mms} file{'s' if num_mms > 1 else ''} with different content"
            raise FailedFilesTestException(ref_only, target_only, mismatches, message)
        if ref_only or target_only:
            raise FailedFilesTestException(ref_only, target_only, mismatches, '')


class FailedFilesTestException(Exception):
    """Exception subclass created to handle test failures separatedly from unexpected exceptions."""
