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
"""CITest abstract classes."""

__all__ = ['CITestMeta', 'CITestItem']

from abc import ABC, ABCMeta, abstractmethod
from collections import OrderedDict
from typing import Dict, Optional, Tuple, Union

import py
import pytest


class CITestMeta(ABCMeta, type(pytest.Item)):  # type: ignore
    """Metaclass required to solve the metaclass conflict in CITestItem."""


class CITestItem(ABC, pytest.Item, metaclass=CITestMeta):
    """Abstract class of the test set to compare two (analogous) Ensembl Compara elements.

    Args:
        name: Name of the test to run.
        parent: The parent collector node.
        args: Arguments to pass to the test call.

    Attributes:
        args (Dict): Arguments to pass to the test call.
        error_info (OrderedDict): Additional information provided when a test fails.

    """
    def __init__(self, name: str, parent: pytest.Item, args: Dict) -> None:
        super().__init__(name, parent)
        self.args = args
        self.error_info = OrderedDict()  # type: OrderedDict

    def runtest(self) -> None:
        """Executes the selected test function with the given arguments.

        Raises:
            SyntaxError: If the test function to call does not exist.

        """
        test_method = 'test_' + self.name
        if not hasattr(self, test_method):
            raise SyntaxError(f"Test '{self.name}' not found")
        getattr(self, test_method)(**self.args)

    def reportinfo(self) -> Tuple[Union[py.path.local, str], Optional[int], str]:
        """Returns the location, the exit status and the header of the report section."""
        return self.fspath, None, self.get_report_header()

    @abstractmethod
    def get_report_header(self) -> str:
        """Returns the header to display in the error report."""
