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
"""Add header to homology TSV file."""

from argparse import ArgumentParser
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory


def get_line_count(file_path):
    """Return the line count of the specified file."""
    cmd_args = ["wc", "-l", file_path]
    output = subprocess.check_output(cmd_args, text=True)
    first_line, *_ignored_lines = output.splitlines()
    first_field, *_ignored_fields = first_line.split()
    return int(first_field)


if __name__ == "__main__":

    parser = ArgumentParser(description=__doc__)
    parser.add_argument("-i", "--input_file", required=True, help="Input homology TSV file path.")
    parser.add_argument(
        "-o", "--output_file", required=True, help="Output homology TSV, with header inserted."
    )

    args = parser.parse_args()

    in_file_path = Path(args.input_file)
    out_file_path = Path(args.output_file)

    exp_line_count = get_line_count(in_file_path) + 1

    hom_tsv_col_names = [
        "gene_stable_id",
        "protein_stable_id",
        "species",
        "identity",
        "homology_type",
        "homology_gene_stable_id",
        "homology_protein_stable_id",
        "homology_species",
        "homology_identity",
        "dn",
        "ds",
        "goc_score",
        "wga_coverage",
        "is_high_confidence",
        "homology_id",
    ]

    hom_tsv_header_line = "\t".join(hom_tsv_col_names) + "\n"

    out_file_path.parent.mkdir(mode=0o775, parents=True, exist_ok=True)
    with TemporaryDirectory(dir=out_file_path.parent, prefix=".tmp_hom_tsv_") as tmp_dir:
        tmp_file_name = out_file_path.name
        tmp_file_path = Path(tmp_dir) / tmp_file_name

        with open(tmp_file_path, mode="w", encoding="utf-8") as out_text_file_obj:
            out_text_file_obj.write(hom_tsv_header_line)

        with open(tmp_file_path, mode="ab") as out_file_obj:
            with open(in_file_path, mode="rb") as in_file_obj:
                shutil.copyfileobj(in_file_obj, out_file_obj)

        num_header_lines = 0
        with open(tmp_file_path, encoding="utf-8") as in_text_file_obj:
            for line in in_text_file_obj:
                if line != hom_tsv_header_line:
                    break
                num_header_lines += 1

        if num_header_lines != 1:
            raise ValueError(
                f"expected exactly one header line in output file '{tmp_file_name}',"
                f" but found {num_header_lines} header lines"
            )

        obs_line_count = get_line_count(tmp_file_path)
        if obs_line_count != exp_line_count:
            raise ValueError(
                f"line-count mismatch in homology TSV file '{tmp_file_name}':"
                f" {obs_line_count} (observed) vs {exp_line_count} (expected)"
            )

        shutil.move(tmp_file_path, out_file_path)
