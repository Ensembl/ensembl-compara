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
"""Collection of utils methods targeted to diverse topics and applications.

Typical usage examples::

    >>> from ensembl.compara.utils.tools import *
    >>> print(to_list('3'))
    ['3']

"""

__all__ = ["import_module_from_file", "to_list"]

from importlib.abc import Loader
from importlib.machinery import ModuleSpec
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import sys
from types import ModuleType
from typing import Any, List, Optional, Union


def import_module_from_file(module_file: Union[Path, str]) -> ModuleType:
    """Import module from file path.

    The name of the imported module is the basename of the specified module
    file without its extension.

    In addition to being returned by this function, the imported module is
    loaded into the sys.modules dictionary, allowing for commands such as
    :code:`from <module> import <class>`.

    Args:
        module_file: File path of module to import.

    Returns:
        The imported module.
    """
    if not isinstance(module_file, Path):
        module_file = Path(module_file)
    module_name = module_file.stem

    module_spec = spec_from_file_location(module_name, module_file)

    if not isinstance(module_spec, ModuleSpec):
        raise ImportError(f"ModuleSpec not created for module file '{module_file}'")
    if not isinstance(module_spec.loader, Loader):
        raise ImportError(f"no loader found for module file '{module_file}'")

    module = module_from_spec(module_spec)
    sys.modules[module_name] = module
    module_spec.loader.exec_module(module)

    return module


def to_list(x: Optional[Any]) -> List:
    """Returns the list version of `x`.

    Returns:
        `x` if `x` is a list, a list containing `x` if `x` is not a list and ``bool(x)`` is True, and an empty
        list otherwise.
    """
    if not x:
        return []
    if not isinstance(x, list):
        return [x]
    return x
