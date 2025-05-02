#!/usr/bin/env python3
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Update an allowed-species JSON file from an MLSS config file.

This script requires that all the relevant genomes in the
MLSS config file have been configured with genome elements.
"""

import argparse
import json

from lxml import etree


def make_allowed_species_from_mlss_conf(mlss_conf_file: str, allowed_sp_file: str) -> None:
    """Make allowed species from mlss_conf.xml file.

    Args:
        mlss_conf_file: Input mlss_conf.xml file in which collections
            are exclusively configured with 'genome' elements.
        allowed_sp_file: Output allowed-species JSON file.
    """
    prod_names = set()
    with open(mlss_conf_file, encoding="ascii") as in_file_obj:
        xml_tree = etree.parse(in_file_obj)  # pylint: disable=c-extension-no-member
        root_elem = xml_tree.getroot()
        for collection_elem in root_elem.findall(".//collection"):
            collection_name = collection_elem.attrib["name"]
            for child_elem in collection_elem.getchildren():
                if child_elem.tag is etree.Comment:  # pylint: disable=c-extension-no-member
                    continue
                if child_elem.tag == "genome":
                    if child_elem.attrib.get("exclude", False):
                        continue
                    prod_names.add(child_elem.attrib["name"])
                else:
                    raise ValueError(
                        f"cannot list allowed species - child of collection '{collection_name}'"
                        f" is a '{child_elem.tag}' element, but must be a 'genome' element"
                    )

    allowed_species = sorted(prod_names)
    with open(allowed_sp_file, "w", encoding="ascii") as out_file_obj:
        json.dump(allowed_species, out_file_obj, indent=4)
        out_file_obj.write("\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mlss_conf_file", metavar="PATH", help="Input MLSS config file.")
    parser.add_argument("allowed_species_file", metavar="PATH", help="Output allowed-species file.")
    args = parser.parse_args()

    make_allowed_species_from_mlss_conf(args.mlss_conf_file, args.allowed_species_file)
