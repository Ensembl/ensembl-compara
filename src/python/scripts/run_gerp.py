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

If ``gerpcol`` and/or ``gerpelem`` are not accessible from ``$PATH``, you will need to provide the
path where they can be found::

    $ python run_gerp.py --msa_file alignment.mfa --tree_file tree.nw --gerp_exe_dir path/to/gerp/

"""
import argparse
import json
import os
import subprocess

def add_ce_to_json(ce_file: str, json_file: str) -> None:
    """Enrich the json file with the constrained elements.

    Args:
        ce_file: file containing the constrained elements (space-delimited format).
        json_file: json file with genome coordinate level.

    """
    with open(json_file, 'r') as json_file_obj:
        align_set = json.load(json_file_obj)

    constrained_elems = []
    with open(ce_file) as ce_file_obj:
        # enrich json file with constrained elements info
        for cons_elem in ce_file_obj:
            if cons_elem.rstrip() == "":
                continue
            ce = cons_elem.split()
            constrained_elem = {
                "start": int(ce[0]),
                "end": int(ce[1]),
                "length": int(ce[2]),
                "score": float(ce[3]),
                "p-val": float(ce[4])
            }
            constrained_elems.append(constrained_elem)
    align_set["constrained_elems"] = constrained_elems

    with open(json_file, 'w') as json_file_obj:
        json.dump(align_set, json_file_obj)


def main(param: argparse.Namespace) -> None:
    """ Main function of the run_gerp.py script

    This function runs gerpcol to define a GERP score for every column of the genomic alignment block
    and gerpelem to identify constrained elements across the genomic alignment block.

    Args:
        param: argparse.Namespace storing all the script parameters

    """

    cmd = ["gerpcol", "-t", param.tree_file, "-f", param.msa_file]
    cmd[0] = os.path.join(param.gerp_exe_dir, cmd[0])
    subprocess.run(cmd, check=True)

    # By default, gerpcol's ouput filename has the MSA filename plus ".rates" suffix
    cmd = ["gerpelem", "-f", f"{param.msa_file}.rates"]
    cmd[0] = os.path.join(param.gerp_exe_dir, cmd[0])
    cmd += ["-d", str(param.depth_threshold)]
    subprocess.run(cmd, check=True)

    add_ce_to_json(f"{param.msa_file}.rates.elems", f"{os.path.splitext(param.msa_file)[0]}.json")


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Calculate GERP score and identify constrained elements.")
    parser.add_argument("--msa_file", type=str, required=True, help="MSA file (MFA format) (REQUIRED)")
    parser.add_argument("--tree_file", type=str, required=True, help="Tree file (Newick format). Must "
                                                "include every species in the MSA. (REQUIRED)")
    parser.add_argument("--depth_threshold", default=0.5, type=float, help="Constrained elements depth "
                                                "threshold for shallow columns, in substitutions per site. "
                                                "The default is 0.5.")
    parser.add_argument("--gerp_exe_dir", default="", type=str,
                        help="Path where 'gerpcol' and 'gerpelem' executable binaries can be found."
                             " The default is $PATH.")

    args = parser.parse_args()
    main(args)
