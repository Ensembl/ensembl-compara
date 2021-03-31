#!/usr/bin/env python3

# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Script to create the reference 'allowed_species.json' automatically from the reference 'mlss_conf.xml'."""


import json
import argparse
import xml.etree.ElementTree
from typing import List


def get_species_list(mlss_conf_file: str) -> List:
    """Returns a list with all species present in the mlss_conf.xml. Each species will appear only once

    Args:
        mlss_conf_file: Path to the mlss_conf.xml

    Returns:
        List of species

    Raises:
        xml.etree.ElementTree.ParseError: If ``mlss_conf_file`` cannot be parsed correctly.
    """

    compara_db_tree = xml.etree.ElementTree.parse(mlss_conf_file)

    root = compara_db_tree.getroot()
    genomes = root.findall("./collections/collection/genome")
    species_set = set()
    for genome in genomes:
        species_set.add(genome.get('name'))
    species_list = list(species_set)

    # sort to keep an order that will make easier the allowed species file checking in github
    species_list.sort()

    return species_list


def create_allowed_species_json(species: List, allowed_species_file: str) -> None:
    """Create the json file with the list of allowed species.

    Args:
        species: The list of species
        allowed_species_file: Path to the output json file

    Raises:
        FileNotFoundError: If ``allowed_species_file`` cannot be created (wrong path).
    """

    with open(allowed_species_file, "w") as file_handle:
        json.dump(species, file_handle, indent=4)


def main(mlss_conf_file: str, allowed_species_file: str) -> None:
    """Main function of the script which process the MLSS XML configuration file to get the list of species
    and write the list of allowed species into a JSON file

    Args:
        mlss_conf_file: Path to the mlss_conf.xml
        allowed_species_file: Path to the output allowed_species.json file

    Returns:
        None
    """

    # get the list fo species from the mlss_conf.xml
    species = get_species_list(mlss_conf_file)
    # create the json file with the list of species
    create_allowed_species_json(species, allowed_species_file)


if __name__ == '__main__':
    # argument handling
    parser = argparse.ArgumentParser(description="Creates the JSON file with the list of allowed species from"
                                                 " a MLSS XML configuration file.")
    parser.add_argument('--mlss_conf', help="Path to the MLSS XML configuration file.")
    parser.add_argument('--allowed', help="Path to the allowed species JSON file.")
    args = parser.parse_args()

    main(args.mlss_conf, args.allowed)
