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
"""Methods for processing MLSS configuration XML file.

This module provides the main function, :func:`get_species_set_by_name()`, that parses an MLSS configuration file and returns
a species list for the given species set.

Typical usage example::

    from ensembl.compara.config import get_species_set_by_name
    get_species_set_by_name('path/to/mlss_conf.xml', 'default')

"""

__all__ = ['get_species_set_by_name']

import os
from typing import List
from xml.etree import ElementTree

def get_species_set_by_name(mlss_conf_file: str, species_set_name: str) -> List[str]:
    """Parses `mlss_conf_file` and returns a list of species for the given species set name.

    Args:
        mlss_conf_file: Path to the MLSS configuration XML file.
        species_set_name: Species set (collection) name.

    Returns:
        A list of species (genome names) for the given species set name.

    Raises:
        FileNotFoundError: If `mlss_conf_file` is not found.
        ElementTree.ParseError: If there are issues with parsing `mlss_conf_file`.
        NameError: If there is no species set matching `species_set_name`.
        RuntimeError: If there is more than one species set corresponding to `species_set_name`.

    """
    tree = ElementTree.parse(mlss_conf_file)
    root = tree.getroot()

    collection = [collection for collection in root.iter("collection")
                      if collection.attrib["name"] == species_set_name]

    if len(collection) == 0:
        raise NameError(f"Species set '{species_set_name}' not found.")
    elif len(collection) > 1:
        raise RuntimeError(f"{len(collection)} species sets named '{species_set_name}' found.")

    species_set = [element.attrib["name"] for element in collection[0] if element.tag == "genome"]

    return species_set
