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
"""Generate list of must-reuse species.

Example::

    ${ENSEMBL_ROOT_DIR}/ensembl-compara/scripts/production/list_must_reuse_species.py \
        --input-file ${ENSEMBL_ROOT_DIR}/ensembl-compara/conf/metazoa/must_reuse_collections.json \
        --mlss-conf-file ${ENSEMBL_ROOT_DIR}/ensembl-compara/conf/metazoa/mlss_conf.xml \
        --ensembl-release 111 \
        --output-file must_reuse_species.json

"""

import argparse
import json

from lxml import etree


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Generate list of must-reuse species.")
    parser.add_argument("-i", "--input-file", metavar="PATH", required=True,
                        help="Input must-reuse collection file.")
    parser.add_argument("--mlss-conf-file", metavar="PATH", required=True,
                        help="Input MLSS conf file.")
    parser.add_argument("--ensembl-release", metavar="INT", required=True, type=int,
                        help="Ensembl release.")
    parser.add_argument("-o", "--output-file", metavar="PATH", required=True,
                        help="Output allowed-species JSON file.")

    args = parser.parse_args()


    with open(args.input_file) as in_file_obj:
        muse_reuse_config = json.load(in_file_obj)

    parity = "even" if args.ensembl_release % 2 == 0 else "odd"
    must_reuse_collections = muse_reuse_config[parity]

    with open(args.mlss_conf_file) as in_file_obj:
        xml_tree = etree.parse(in_file_obj)

    xml_root = xml_tree.getroot()

    must_reuse_genomes = set()
    for collection_name in must_reuse_collections:
        collection = xml_root.find(f".//collection[@name='{collection_name}']")
        for genome in collection.findall("genome"):
            if genome.attrib.get("exclude", False):
                continue
            must_reuse_genomes.add(genome.attrib["name"])

    with open(args.output_file, "w") as out_file_obj:
        json.dump(sorted(must_reuse_genomes), out_file_obj)
