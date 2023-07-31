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
"""Python testing helper module."""

__all__ = ["mock_two_bit_to_fa"]

import re
import shlex
import subprocess
from typing import Sequence


def mock_two_bit_to_fa(
    cmd_args: Sequence,
    *args,  # pylint: disable=unused-argument
    **kwargs,  # pylint: disable=unused-argument
) -> None:
    """Mock of ``twoBitToFa`` call to generate expected output file."""
    if cmd_args[0] == "twoBitToFa":
        two_bit_seq_map = {
            "genomeA.2bit": "ATTGTAATCTACGATTAAGTCACAATGATTTGG",
            "genomeB.2bit": "ATTCCCGTAATCTACGAATCATTAAGGCACAACCAAACCA",
        }

        _command, bed_option, two_bit_file, out_fasta_file = cmd_args
        in_bed_file = re.sub("^-bed=", "", bed_option)
        two_bit_seq = two_bit_seq_map[two_bit_file.name]

        with open(in_bed_file, "r") as in_file_obj:
            for line in in_file_obj:
                fields = line.rstrip("\n").split("\t")
                start = int(fields[1])
                end = int(fields[2])

                subseq = two_bit_seq[start:end]
                if len(subseq) != end - start:
                    returncode = 255
                    cmd = shlex.join([str(x) for x in cmd_args])
                    raise subprocess.CalledProcessError(returncode, cmd)

        with open(out_fasta_file, "w") as out_file_obj:
            out_file_obj.write(f">1\n{subseq}\n")
    else:
        raise ValueError(f"cannot mock unknown command arguments: {cmd_args}")
