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
"""Methods for preparing input files and running OrthoFinder.

This module provides::

    :func:`prepare_input_orthofinder()` which copies input fasta files for OrthoFinder
            into a specified working directory

    :func:`run_orthofinder()` which runs OrthoFinder

Typical usage example::

    from ensembl.compara.orthtools import prepare_input_orthofinder
    prepare_input_orthofinder('path/to/source_dir', 'path/to/target_dir')

    from ensembl.compara.orthtools import run_orthofinder
    run_orthofinder('path/to/input/fasta/files')

    from ensembl.compara.orthtools import run_orthofinder
    run_orthofinder('path/to/input/fasta/files', 16, 4)

"""

__all__ = ['prepare_input_orthofinder', 'run_orthofinder']

import fnmatch
import os
import subprocess

def prepare_input_orthofinder(source_dir: str, target_dir: str) -> None:
    """Creates symlinks to input fasta files in `target_dir`.

    Args:
        source_dir: Path to the directory containing fasta files.
        target_dir: Path to the directory where symlinks to fasta files will be created
                for OrthoFinder to use.

    Raises:
        FileExistsError: If directory `target_dir` already exists.
        FileNotFoundError: If directory `source_dir` does not exist or does not contain any fasta files.
        subprocess.CalledProcessError: If creating symlinks fails for some other reason.

    """
    if not os.path.isdir(source_dir):
        raise FileNotFoundError("Directory containing fasta files not found.")
    if len(fnmatch.filter(os.listdir(source_dir), '*.fasta')) == 0:
        raise FileNotFoundError("No fasta files found.")

    # To ensure a new directory is used for running OrthoFinder:
    os.mkdir(target_dir)

    script = os.path.join(os.environ["ENSEMBL_ROOT_DIR"], "ensembl-compara", "scripts", "pipeline",
                          "symlink_fasta.py")

    subprocess.run([script, "-s", target_dir, "-d", source_dir], capture_output=True, check=True)


def run_orthofinder(input_dir: str, number_of_threads: int = 32, number_of_orthofinder_threads: int = 8) \
        -> None:
    """Runs OrthoFinder.

    Args:
        input_dir: Path to the directory containing input fasta files.
        number_of_threads: The number of parallel processes for the BLAST/DIAMOND searches and
                tree inference steps.
        number_of_orthofinder_threads: The number of parallel processes for other OrthoFinder steps
                that have been parallelised.(If not specified at all, defaults to
                min{16, 1/8 * `number_of_threads`}.)

    Raises:
        FileNotFoundError: If OrthoFinder executable (`orthofinder_exe`) cannot be found.
        subprocess.CalledProcessError: If executing OrthoFinder command fails for some reason,
                including `input_dir` not found.

    """
    orthofinder_exe = "/hps/software/users/ensembl/ensw/C8-MAR21-sandybridge/linuxbrew/bin/orthofinder"

    subprocess.run([orthofinder_exe, "-t", str(number_of_threads), "-a", str(number_of_orthofinder_threads),
                    "-f", input_dir], capture_output=True, check=True)
