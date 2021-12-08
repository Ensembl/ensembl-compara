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

Typical usage examples::

    # With pipeline default numbers of threads for OrthoFinder
    $ python orthology_benchmark.py --mlss_conf /path/to/mlss_conf.xml --species_set name \
    --host mysql-ens-compara-prod-X --port XXXX --user username --out_dir /path/to/out/dir \
    ----orthology_input /path/to/orthofinder/input/files

    # With user specified numbers of threads for OrthoFinder & gene tree inference from msa
    $ python orthology_benchmark.py --mlss_conf /path/to/mlss_conf.xml --species_set name \
    --host mysql-ens-compara-prod-X --port XXXX --user username --out_dir /path/to/out/dir \
    ----orthology_input /path/to/orthofinder/input/files --number_of_threads XXXX \
    --number_of_orthofinder_threads XXXX --tree_method msa

"""

import argparse
import fnmatch
import os
from pathlib import Path
import re
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
    dump_cores = list(cores.values())

    if len(dump_cores) == 0:
        raise RuntimeError(f"No cores found for the species set '{species_set_name}' on the specified host.")

    dumps_dir = os.path.join(out_dir, species_set_name)
    os.mkdir(dumps_dir)

    script = os.path.join(os.environ["ENSEMBL_ROOT_DIR"], "ensembl-compara", "scripts", "dumps",
                          "dump_gene_set_from_core.pl")

    for core in dump_cores:
        out_file = os.path.join(dumps_dir, f"{core}.fasta")
        subprocess.run([script, "-core-db", core, "-host", host, "-port", str(port),
                       "-outfile", out_file], capture_output=True, check=True)


def find_latest_core(core_names: List[str]) -> str:
    """Returns the name of the latest available core database.

    The latest refers to the latest Ensembl release and the latest version.

    Args:
        core_names: A list of cores for a species of interest.

    Raises:
        ValueError: If `core_names` is empty.

    """
    if len(core_names) == 0:
        raise ValueError("Empty list of core databases. Cannot determine the latest one.")

    rel_ver = [name.split("_core_")[1].split("_") for name in core_names]
    rel_ver_int = [list(map(int, i)) for i in rel_ver]

    # There might be two types of versioning
    # (e.g. caenorhabditis_elegans_core_106_279, caenorhabditis_elegans_core_53_106_279)
    # Pad with zero(s) on the left (to get e.g. [[0, 106, 279], [53, 106, 279]])
    max_length = max(len(r) for r in rel_ver_int)
    pad_token = 0
    rel_ver_int_pad = [[pad_token] * (max_length - len(r)) + r for r in rel_ver_int]

    rel_ver_arr = numpy.array(rel_ver_int_pad)

    n_cols = rel_ver_arr.shape[1]
    # Skip columns with any padded values
    i = max(max_length - len(r) for r in rel_ver_int)
    while i < n_cols:
        # Find max value in the i-th column
        # For the next iteration (i+1) consider only rows where i-th column == max value
        max_col = numpy.amax(rel_ver_arr[:, i])
        rows_ind = numpy.where(rel_ver_arr[:, i] == max_col)[0]
        rel_ver_arr = rel_ver_arr[[rows_ind], :][0]
        i += 1

    # Trim padded zeros, if any, to get only numbers that appear in the core db name
    rel_ver_trimmed = numpy.trim_zeros(rel_ver_arr[0], "f")
    latest_rel_ver = '_'.join(map(str, rel_ver_trimmed))
    core_name = [core for core in core_names if latest_rel_ver in core][0]

    return core_name


def get_core_names(species_names: List[str], host: str, port: int, user: str) -> Dict[str, str]:
    """Returns the latest core database names for a list of species.

    Args:
        species_names: Species (genome) names.
        host: Host for core databases.
        port: Host port.
        user: Server username.

    Returns:
        Dictionary mapping species (genome) names to the latest version of available core names.

    Raises:
        ValueError: If `species_list` is empty.
        sqlalchemy.exc.OperationalError: If `user` cannot read from `host:port`.

    """
    if len(species_names) == 0:
        raise ValueError("Empty list of species names. Cannot search for core databases.")

    core_names = {}

    eng = create_engine(f"mysql://{user}@{host}:{port}/")
    result = eng.execute("SHOW DATABASES LIKE '%%_core_%%'").fetchall()
    all_cores = [i[0] for i in result]

    user_env = os.environ['USER']
    for species in species_names:
        core_name = [core for core in all_cores if re.match(f"^({user_env}_)?{species}_core_", core)]
        if len(core_name) == 1:
            core_names[species] = core_name[0]
        elif len(core_name) > 1:
            core_names[species] = find_latest_core(core_name)

    return core_names


def prep_input_for_orth_tools(source_dir: str, target_dir: str) -> None:
    """Prepares input files for selected orthology inference tools.

    Creates symlinks to input fasta files in `target_dir`.

    Args:
        source_dir: Path to the directory containing .fasta files.
        target_dir: Path to the directory where symlinks to .fasta files will be created.

    Raises:
        FileExistsError: If directory `target_dir` already exists.
        FileNotFoundError: If directory `source_dir` does not exist or does not contain any .fasta files.
        subprocess.CalledProcessError: If creating symlinks fails for some other reason.
    """
    if not os.path.isdir(source_dir):
        raise FileNotFoundError("Directory containing .fasta files not found.")
    if len(fnmatch.filter(os.listdir(source_dir), '*.fasta')) == 0:
        raise FileNotFoundError("No .fasta files found.")

    # OrthoFinder
    os.mkdir(target_dir)
    script_symlinks = os.path.join(Path(__file__).parents[2], "scripts", "pipeline", "symlink_fasta.py")
    subprocess.run([script_symlinks, "-d", source_dir, "-s", target_dir],
                   capture_output=True, check=True)


def run_orthology_tools(input_dir: str, number_of_threads: int, number_of_orthofinder_threads: int,
                        tree_method: str) -> None:
    """Runs the selected orthology inference tool.

    Args:
        input_dir: Path to the directory containing the input fasta files (or corresponding symlinks) for
            orthology tools.
        number_of_threads: The number of threads OrthoFinder will use for running the BLAST searches,
            tree inference and gene-tree reconciliation in parallel.
        number_of_orthofinder_threads: The number of parallel processes for other OrthoFinder steps
            that have been parallelised.
        tree_method: Method for OrthoFinder gene tree inference: 'dendroblast' or 'msa'.

    Raises:
        FileNotFoundError: If OrthoFinder executable (`orthofinder_exe`) cannot be found.
        subprocess.CalledProcessError: If executing OrthoFinder command fails for some reason,
            including `input_dir` not found.
    """
    # OrthoFinder
    orthofinder_exe = "/hps/software/users/ensembl/ensw/C8-MAR21-sandybridge/linuxbrew/bin/orthofinder"
    subprocess.run([orthofinder_exe, "-t", str(number_of_threads), "-a", str(number_of_orthofinder_threads),
                    "-M", tree_method, "-f", input_dir], capture_output=True, check=True)


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
    parser.add_argument("--out_dir", required=True, type=str,
                        help="Location for 'species_set/core_name.fasta' dumps")
    parser.add_argument("--orthology_input", required=True, type=str,
                        help="Location of input files for orthology tools")
    parser.add_argument("--number_of_threads", default=32, type=int,
                        help="OrthoFinder parameter '-t'")
    parser.add_argument("--number_of_orthofinder_threads", default=8, type=int,
                        help="OrthoFinder parameter '-a'")
    parser.add_argument("--tree_method", default="dendroblast", type=str,
                        help="OrthoFinder parameter '-M'")

    args = parser.parse_args()

    print("Getting a list of species...")
    genome_list = get_species_set_by_name(args.mlss_conf, args.species_set)
    print("Dumping cores into fasta files...")
    dump_genomes(genome_list, args.species_set, args.host, args.port, args.user, args.out_dir)
    print("Preparing input for orthology inference tools...")
    prep_input_for_orth_tools(os.path.join(args.out_dir, args.species_set), args.orthology_input)
    print("Running orthology inference tools...")
    run_orthology_tools(args.orthology_input, args.number_of_threads, args.number_of_orthofinder_threads,
                        args.tree_method)
    # prep_input_for_goc()
    # calculate_goc_scores()
