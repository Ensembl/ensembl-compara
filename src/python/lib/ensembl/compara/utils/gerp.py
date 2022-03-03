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

    $ python gerp.py --msa_file alignment.mfa --tree_file tree.nw

If ``gerpcol`` and/or ``gerpelem`` are not accesible from ``$PATH``, you will need to provide the
path where they can be found::

    $ python gerp.py --msa_file alignment.mfa --tree_file tree.nw --gerp_exe_dir path/to/gerp/

"""

__all__ = ['main']

import os
import subprocess

import argschema


class InputSchema(argschema.ArgSchema):
    """Calculates the Genomic Evolutionary Rate Profiling (GERP) of a multiple sequence alignment (MSA)."""

    msa_file = argschema.fields.InputFile(
        required=True, description="MSA file (MFA format)"
    )
    tree_file = argschema.fields.InputFile(
        required=True, description="Tree file (Newick format). Must include every species in the MSA."
    )
    depth_threshold = argschema.fields.Float(
        required=False,
        description="Constrained elements' depth threshold for shallow columns, in substitutions "
                    "per site. By default, 0.5."
    )
    gerp_exe_dir = argschema.fields.InputDir(
        required=False,
        description="Path where 'gerpcol' and 'gerpelem' binaries can be found. By default, resort to $PATH."
    )


def main(msa_file: str, tree_file: str, depth_threshold: float = None, gerp_exe_dir: str = None) -> None:
    """Calculates the conservation scores and constrained elements of the given MSA.
    
    Args:
        msa_file: MSA file (MFA format)
        tree_file: Tree file (Newick format)
        depth_threshold: Constrained elements' depth threshold for shallow columns, in substitutions per site
        gerp_exe_dir: Path where `gerpcol` and `gerpelem` binaries can be found
    
    """
    cmd = ["gerpcol", "-t", tree_file, "-f", msa_file]
    if gerp_exe_dir:
        cmd[0] = os.path.join(gerp_exe_dir, cmd[0])
    subprocess.run(cmd, check=True)
    # By default, gerpcol's ouput filename has the MSA filename plus ".rates" suffix
    cmd = ["gerpelem", "-f", f"{msa_file}.rates"]
    if gerp_exe_dir:
        cmd[0] = os.path.join(gerp_exe_dir, cmd[0])
    if depth_threshold:
        cmd += ["-d", str(depth_threshold)]
    subprocess.run(cmd, check=True)


if __name__ == "__main__":
    mod = argschema.ArgSchemaParser(schema_type=InputSchema)
    main(**mod.args)
