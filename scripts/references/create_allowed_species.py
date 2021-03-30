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

""" Script to create the reference allowed_species.json automatically form the reference mlss_conf.xml """


import sys
import json
import argparse
import xml.etree.ElementTree
from xml.etree.ElementTree import ParseError
from typing import List


def get_species_list(mlss_conf_file: str) -> List:
    """
    Return a list with all species present in the mlss_conf.xml. Each species are unci in the list

    :param mlss_conf_file: path to the mlss_conf.xml
    :return: list of species
    """

    try:
        compara_db_tree = xml.etree.ElementTree.parse(mlss_conf_file)
    except ParseError as err:
        print("issue with " + mlss_conf_file)
        print(err)
        sys.exit(1)

    root = compara_db_tree.getroot()
    genomes = root.findall("./collections/collection/genome")
    species_dic = {}
    for genome in genomes:
        species_dic[genome.get('name')] = 1
    species_list = list(species_dic.keys())
    return species_list


def create_allowed_species_json(species: List, allowed_species_file: str) -> None:
    """
    Create the json file with th list of allowed species

    :param species: the list of species
    :param allowed_species_file: path to the output json file
    :return: None
    """

    with open(allowed_species_file, "w") as file_handle:
        json.dump(species, file_handle, indent=4)


def main(mlss_conf_file: str, allowed_species_file: str) -> None:
    """
    Main function of the script

    :param mlss_conf_file: path to the mlss_conf.xml
    :param allowed_species_file: path to the output allowed_species.json file
    :return: None
    """

    # get the list fo species from the mlss_conf.xml
    species = get_species_list(mlss_conf_file)
    # create the json file with the list of species
    create_allowed_species_json(species, allowed_species_file)


if __name__ == '__main__':
    # argument handling
    parser = argparse.ArgumentParser()
    parser.add_argument('--mlss_conf', help="path to mlss_conf.xml file given as input")
    parser.add_argument('--allowed', help="path to the allowed_species.json given as output")
    args = parser.parse_args()

    main(args.mlss_conf, args.allowed)
