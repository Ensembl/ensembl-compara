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

    # To list species that must be reused in release 111:
    ${ENSEMBL_ROOT_DIR}/ensembl-compara/scripts/production/list_must_reuse_species.py \
        --input-file ${ENSEMBL_ROOT_DIR}/ensembl-compara/conf/metazoa/must_reuse_collections.json \
        --mlss-conf-file ${ENSEMBL_ROOT_DIR}/ensembl-compara/conf/metazoa/mlss_conf.xml \
        --ensembl-release 111 \
        --output-file must_reuse_species.json

    # To list species that must always be reused, assuming the
    # current collections are updated in alternating releases:
    ${ENSEMBL_ROOT_DIR}/ensembl-compara/scripts/production/list_must_reuse_species.py \
        --input-file ${ENSEMBL_ROOT_DIR}/ensembl-compara/conf/metazoa/must_reuse_collections.json \
        --mlss-conf-file ${ENSEMBL_ROOT_DIR}/ensembl-compara/conf/metazoa/mlss_conf.xml \
        --ensembl-release all \
        --output-file always_reuse_species.json

"""

import argparse
from collections import defaultdict
import itertools
import json

from lxml import etree


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate list of must-reuse species.")
    parser.add_argument(
        "-i",
        "--input-file",
        metavar="PATH",
        required=True,
        help="Input reused collection config file.",
    )
    parser.add_argument(
        "--mlss-conf-file",
        metavar="PATH",
        required=True,
        help="Input MLSS conf file.",
    )
    parser.add_argument(
        "--ensembl-release",
        metavar="VALUE",
        required=True,
        help="Ensembl release, or 'all' to list 'always-reused' species.",
    )
    parser.add_argument(
        "-o",
        "--output-file",
        metavar="PATH",
        required=True,
        help="Output JSON file listing must-reuse species.",
    )

    args = parser.parse_args()

    with open(args.input_file) as in_file_obj:
        reused_collection_conf = json.load(in_file_obj)

    reused_collection_names = sorted(itertools.chain.from_iterable(reused_collection_conf.values()))

    with open(args.mlss_conf_file) as in_file_obj:
        xml_tree = etree.parse(in_file_obj)

    xml_root = xml_tree.getroot()

    reused_collection_genomes = defaultdict(set)
    for collection_name in reused_collection_names:
        collection = xml_root.find(f".//collection[@name='{collection_name}']")
        for genome in collection.findall("genome"):
            if genome.attrib.get("exclude", False):
                continue
            reused_collection_genomes[collection_name].add(genome.attrib["name"])

    reused_genomes_by_parity = {}
    for parity in ["odd", "even"]:
        reused_genomes_by_parity[parity] = set.union(
            *[reused_collection_genomes[collection] for collection in reused_collection_conf[parity]]
        )

    if args.ensembl_release == "all":
        must_reuse_genomes = reused_genomes_by_parity["odd"] & reused_genomes_by_parity["even"]
    else:
        try:
            ensembl_release = int(args.ensembl_release)
        except ValueError as exc:
            raise ValueError(f"invalid/unsupported Ensembl release: {args.ensembl_release}") from exc
        parity = "even" if ensembl_release % 2 == 0 else "odd"
        must_reuse_genomes = reused_genomes_by_parity[parity]

    with open(args.output_file, "w") as out_file_obj:
        json.dump(sorted(must_reuse_genomes), out_file_obj)
