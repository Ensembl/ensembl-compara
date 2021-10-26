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

__all__ = ['to_list']

from typing import Any, Optional, List


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
