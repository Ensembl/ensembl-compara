#!/usr/bin/env python3
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
"""Pipeline for benchmarking orthology inference tools.

Typical usage example::

    $ python orthology_benchmark.py --mlss_conf /path/to/mlss_conf.xml \
        --species_set default

"""

import argparse

from ensembl.compara.config import get_species_set_by_name


def dump_genomes():
    """Docstring"""


def prep_input_for_orth_tools():
    """Docstring"""


def run_orthology_tools():
    """Docstring"""


def prep_input_for_goc():
    """Docstring"""


def calculate_goc_scores():
    """Docstring"""


if __name__ == '__main__':

    parser = argparse.ArgumentParser()
    parser.add_argument("--mlss_conf", required=True, type=str, help="Path to MLSS configuration XML file")
    parser.add_argument("--species_set", required=True, type=str, help="Species set (collection) name")

    args = parser.parse_args()

    species_list = get_species_set_by_name(args.mlss_conf, args.species_set)
    # dump_genomes(species_list, ...)
    # prep_input_for_orth_tools()
    # run_orthology_tools()
    # prep_input_for_goc()
    # calculate_goc_scores()
