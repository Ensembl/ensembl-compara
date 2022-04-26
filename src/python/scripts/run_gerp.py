#!/usr/bin/env python
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
"""Calculates the Genomic Evolutionary Rate Profiling (GERP) of a multiple sequence alignment.

GERP will produce two files, one with the conservation scores (suffixed with ".rates") and another with
the constrained elements (suffixed with ".elems").

Typical usage example::

    $ python run_gerp.py --msa_file alignment.mfa --tree_file tree.nw

If ``gerpcol`` and/or ``gerpelem`` are not accesible from ``$PATH``, you will need to provide the
path where they can be found::

    $ python run_gerp.py --msa_file alignment.mfa --tree_file tree.nw --gerp_exe_dir path/to/gerp/

"""
import os
import subprocess
import argparse
import json


def add_ce_to_json(ce_file: str, json_file: str) -> None:
    """Enrich the json file with the constrained elements

    Args:
        ce_file: file containing the constrained elements.
        json_file: json file with genome coordinate level.

    Returns:
        None
    """
    with open(json_file, 'r') as json_file_handler:
        align_set = json.load(json_file_handler)

    with open(ce_file) as ce_file_handler:
        constrained_elements = [ce.split() for ce in ce_file_handler if ce.rstrip() != ""]

    # enrich json file with constrained elements info
    constrained_elems = []
    for ce in constrained_elements:
        constrained_elem = {}
        constrained_elem["start"] = ce[0]
        constrained_elem["end"] = ce[1]
        constrained_elem["length"] = ce[2]
        constrained_elem["score"] = ce[3]
        constrained_elem["p-val"] = ce[4]
        constrained_elems.append(constrained_elem)
    align_set["constraint_elems"] = constrained_elems

    with open(json_file, 'w') as json_file_handler:
        json.dump(align_set, json_file_handler)


def main(param: argparse.Namespace) -> None:
    ''' Main function of the run_gerp.py script

    This function is running gerpcol that define a gerpscore for every column of the genomic alignment bloc
    and gerpelem that identify constrained elements across the alignment bloc

    Args:
        param: argparse.Namespace storing all the script parameters

    Returns:
        None
    '''

    cmd = ["gerpcol", "-t", param.tree_file, "-f", param.msa_file]
    cmd[0] = os.path.join(param.gerp_exe_dir, cmd[0])
    subprocess.run(cmd, check=True)

    # By default, gerpcol's ouput filename has the MSA filename plus ".rates" suffix
    cmd = ["gerpelem", "-f", f"{param.msa_file}.rates"]
    cmd[0] = os.path.join(param.gerp_exe_dir, cmd[0])
    cmd += ["-d", str(param.depth_threshold)]
    subprocess.run(cmd, check=True)

    add_ce_to_json(f"{param.msa_file}.rates.elems", param.msa_file.replace(".fa", ".json"))


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Calculate GERP score and identify constraint elements.')
    parser.add_argument('--msa_file', type=str, required=True, help='MSA file (MFA format) (REQUIRED)')
    parser.add_argument('--tree_file', type=str, required=True, help='Tree file (Newick format). Must '
                                                'include every species in the MSA. (REQUIRED)')
    parser.add_argument('--depth_threshold', default=0.5, type=float, help='Constrained elements depth '
                                                'threshold for shallow columns, in substitutions per site. '
                                                'By default, 0.5.')
    parser.add_argument('--gerp_exe_dir', default="", type=str, help='Path where "gerpcol" and "gerpelem" '
                                                'binaries can be found. By default, resort to $PATH.')

    args = parser.parse_args()
    main(args)
