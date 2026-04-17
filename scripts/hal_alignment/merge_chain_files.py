#!/usr/bin/env python3
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
"""Merge chain files.

The input chain files are assumed to be named with
an integer prefix which can be used to order them.
"""

import argparse
from pathlib import Path
import re


def main() -> None:
    """Main function of script."""

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("chain_list_file", help="Input file listing chain files to merge, one per line.")
    parser.add_argument("merged_chain_file", help="Output merged chain file.")

    args = parser.parse_args()

    with open(args.chain_list_file, encoding="utf-8") as in_file_obj:
        chain_file_paths = [Path(line.rstrip()) for line in in_file_obj]

    greedy_file_suffix_re = re.compile(r"\..+$")

    chain_file_paths.sort(key=lambda x: int(greedy_file_suffix_re.sub("", str(x.name))))

    exp_chain_col_count = 13
    next_chain_id = 1
    with open(args.merged_chain_file, mode="w", encoding="utf-8") as out_file_obj:
        for chain_file_path in chain_file_paths:
            with open(chain_file_path, encoding="utf-8") as in_file_obj:
                for line in in_file_obj:
                    if line.startswith("chain"):
                        line = line.rstrip()
                        fields = line.split()
                        if len(fields) != exp_chain_col_count:
                            raise ValueError(
                                f"found {len(fields)} columns in chain header,"
                                f" but expected {exp_chain_col_count}"
                            )
                        fields[-1] = str(next_chain_id)
                        line = " ".join(fields) + "\n"
                        next_chain_id += 1
                    out_file_obj.write(line)


if __name__ == "__main__":
    main()
