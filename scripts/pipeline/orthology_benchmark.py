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

    $ python orthology_benchmark.py --mlss_conf /path/to/mlss_conf.xml --species_set name \
    --host mysql-ens-compara-prod-X --port XXXX --user ensro --out_dir /path/to/out/dir

"""

import argparse
import os
import subprocess
from typing import Dict, List

import numpy
from sqlalchemy import create_engine

from ensembl.compara.config import get_species_set_by_name


def dump_genomes(species_list: List[str], species_set_name: str, host: str, port: int,
                 user: str, out_dir: str) -> None:
    """Dumps canonical peptides of protein-coding genes for a specified list of species.

    Peptides are dumped from the latest available core databases to FASTA files
    using `dump_gene_set_from_core.pl`.

    Args:
        species_list: A list of species (genome) names to dump.
        species_set_name: Species set (collection) name.
        host: Database host.
        port: Host port.
        user: Server username.
        out_dir: Directory to place `species_set_name/core_name.fasta` dumps.

    Raises:
        FileExistsError: If directory `out_dir/species_set_name` already exists.
        sqlalchemy.exc.OperationalError: If `user` cannot read from `host:port`.
        RuntimeError: If no cores are found for any species in `species_list` (`species_set_name`)
                on `host:port`.

    """
    cores = get_core_names(species_list, host, port, user)
    dump_cores = [core for species, core in cores.items() if core != ""]

    if len(dump_cores) == 0:
        raise RuntimeError(f"No cores found for the species set '{species_set_name}' on host '{host}'.")

    dumps_dir = os.path.join(out_dir, species_set_name)
    os.mkdir(dumps_dir)

    script = os.path.join(os.environ["ENSEMBL_ROOT_DIR"], "ensembl-compara", "scripts", "dumps",
                          "dump_gene_set_from_core.pl")

    for core in dump_cores:
        out_file = os.path.join(dumps_dir, core + ".fasta")
        subprocess.run([script, "-core-db", core, "-host", host, "-port", str(port),
                       "-outfile", out_file], capture_output=True, check=True)


def find_latest_core(core_names: List[str]) -> str:
    """Returns the latest core database among the available ones.

    Args:
        core_names: A list of cores for a species of interest.

    Raises:
        RuntimeError: If `core_names` is empty.

    Returns:
        Name of the latest core database (the latest Ensembl release, the latest version).

    """
    if len(core_names) == 0:
        raise RuntimeError("Empty list of core databases. Cannot determine the latest one.")

    rel_ver = [name.split("_core_")[1].split("_") for name in core_names]
    rel_ver_int = [list(map(int, i)) for i in rel_ver]
    rel_ver_arr = numpy.array(rel_ver_int)

    n_cols = rel_ver_arr.shape[1]
    i = 0
    while i < n_cols:
        # Find max value in the i-th column
        # For the next iteration (i+1) consider only rows where i-th column == max value
        max_col = numpy.amax(rel_ver_arr[:, i])
        rows_ind = numpy.where(rel_ver_arr[:, i] == max_col)[0]
        rel_ver_arr = rel_ver_arr[[rows_ind], :][0]
        i += 1

    latest_rel_ver = '_'.join(map(str, rel_ver_arr[0]))
    core_name = [core for core in core_names if latest_rel_ver in core][0]

    return core_name


def get_core_names(species_names: List[str], host: str, port:int, user: str) -> Dict[str, str]:
    """Returns the latest core database names for a list of species.

    Args:
        species_names: Species (genome) names.
        host: Host for core databases.
        port: Host port.
        user: Server username.

    Raises:
        RuntimeError: If `species_list` is empty.
        sqlalchemy.exc.OperationalError: If `user` cannot read from `host:port`.

    Returns:
        Dictionary mapping species (genome) names to the latest version of available core names.

    """
    if len(species_names) == 0:
        raise RuntimeError("Empty list of species names. Cannot search for core databases.")

    core_names = {}

    eng = create_engine("mysql://" + user + "@" + host + ":" + str(port) + "/")
    out_tmp = eng.execute("SHOW DATABASES LIKE '%%_core_%%'").fetchall()
    all_cores = [i[0] for i in out_tmp]

    for species in species_names:
        core_name = [core for core in all_cores if species + "_core_" in core]
        if len(core_name) == 0:
            core_names[species] = ""
        elif len(core_name) == 1:
            core_names[species] = core_name[0]
        else:
            core_names[species] = find_latest_core(core_name)

    return core_names


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
    parser.add_argument("--host", required=True, type=str, help="Database host")
    parser.add_argument("--port", required=True, type=int, help="Database port")
    parser.add_argument("--user", required=True, type=str, help="Server username")
    parser.add_argument("--out_dir", required=True, type=str, help="Location for"
                                                                   "'species_set/core_name.fasta' dumps")

    args = parser.parse_args()

    genome_list = get_species_set_by_name(args.mlss_conf, args.species_set)
    dump_genomes(genome_list, args.species_set, args.host, args.port, args.user, args.out_dir)
    # prep_input_for_orth_tools()
    # run_orthology_tools()
    # prep_input_for_goc()
    # calculate_goc_scores()
