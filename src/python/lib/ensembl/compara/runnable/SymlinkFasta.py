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

"""Runnable to symlink a fasta file into a set directory.

Optionally cleans up broken symlinks first. By default cleanup_symlinks is False.

"""

import subprocess
from typing import Dict

import eHive

class SymlinkFasta(eHive.BaseRunnable):
    """Symlinks a fasta file into a specified directory"""

    def param_defaults(self) -> Dict[str, bool]:
        """set default parameters"""
        return {
            'cleanup_symlinks': False,
        }

    def run(self) -> None:
        """grab fasta and symlink"""

        # Executable script to run
        symlink_exe = self.param_required('symlink_fasta_exe')
        # Directory path to symlink fasta files in single level directory
        symlink_dir = self.param_required('symlink_dir')
        cleanup_symlinks = self.param('cleanup_symlinks')

        if self.param('target_file') is not None:
            target = f"--target_file {self.param('target_file')}"
        else:
            target = f"--target_dir {self.param('target_dir')}"

        # Run symlink_exe script
        cmd = ' '.join([symlink_exe, target, '--symlink_dir', symlink_dir])
        if cleanup_symlinks is not None:
            cmd += ' --cleanup_symlinks'
        subprocess.run(cmd, check=True, shell=True)

    def write_output(self) -> None:
        """dataflow shared_dir"""

        self.dataflow({'symlink_dir': self.param_required('symlink_dir')}, 1)
