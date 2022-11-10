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
"""Prepare QfO reference proteome files for processing."""

import argparse
import json
import os
from pathlib import Path
import re
from tarfile import TarFile
from tempfile import TemporaryDirectory
from typing import Dict, Union

from Bio import SeqIO


def parse_qfo_proteome_table(qfo_readme_file: Union[str, Path]) -> Dict:
    """Parse table in QfO reference proteome README file.

    Args:
        qfo_readme_file: Input QfO reference proteome README file.

    Returns:
        Dictionary containing QfO reference proteome metadata.

    """
    qfo_species_header_re = re.compile(
        r"Proteome_ID\s+Tax_ID\s+OSCODE\s+SUPERREGNUM\s+#\(1\)\s+#\(2\)\s+#\(3\)\s+Species_Name"
    )

    table_lines = []
    with open(qfo_readme_file) as file_obj:
        reading_table = False
        for line in file_obj:
            line = line.rstrip("\n")
            if qfo_species_header_re.fullmatch(line):
                reading_table = True
                continue
            if reading_table and line == "":
                break
            if reading_table:
                table_lines.append(line)

    if not table_lines:
        raise RuntimeError(f"failed to extract QfO proteome table from '{qfo_readme_file}'")

    proteome_meta = {}
    for table_line in table_lines:
        proteome_id, tax_id, _, superregnum, *_unused, species_name = table_line.split(maxsplit=7)
        sub_dir = superregnum.capitalize()

        species_name = re.sub(r"\(.+$", "", species_name).rstrip()
        species_name = re.sub(r"\s+", "_", species_name)
        species_name = species_name.lower()
        species_name = re.sub("[^a-z0-9_]", "", species_name)

        if species_name in proteome_meta:
            raise ValueError(f"duplicate species production name: {species_name}")

        proteome_meta[species_name] = {
            "proteome_id": proteome_id,
            "tax_id": int(tax_id),
            "sub_dir": sub_dir,
        }

    return proteome_meta


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Prepare QfO reference proteome files for processing.")
    parser.add_argument("qfo_archive",
                        help="Input QfO archive file.")
    parser.add_argument("meta_file",
                        help="Output JSON file of proteome metadata.")
    parser.add_argument("output_dir",
                        help="Directory to which proteome data will be output.")

    args = parser.parse_args()

    with TemporaryDirectory() as tmp_dir:

        with TarFile.open(args.qfo_archive) as tar_file:
            tar_file.extractall(tmp_dir)

        readme_file = os.path.join(tmp_dir, "README")
        uniprot_meta = parse_qfo_proteome_table(readme_file)

        out_dir = os.path.abspath(args.output_dir)
        os.makedirs(out_dir, exist_ok=True)

        source_meta = []
        for prod_name, meta in uniprot_meta.items():
            in_dir = os.path.join(tmp_dir, meta["sub_dir"])

            in_cds_file_path = os.path.join(in_dir, f"{meta['proteome_id']}_{meta['tax_id']}_DNA.fasta")
            out_cds_file_path = os.path.join(out_dir, f"{meta['tax_id']}_{prod_name}.cds.fasta")

            cds_ids = set()
            with open(in_cds_file_path) as in_file_obj, open(out_cds_file_path, "w") as out_file_obj:
                for rec in SeqIO.parse(in_file_obj, "fasta"):
                    db_name, uniq_id, entry_name = rec.id.split("|")
                    if set(str(rec.seq)) <= set("ACGTN"):
                        SeqIO.write([rec], out_file_obj, "fasta")
                        cds_ids.add(uniq_id)

            in_prot_file_path = os.path.join(in_dir, f"{meta['proteome_id']}_{meta['tax_id']}.fasta")
            out_prot_file_path = os.path.join(out_dir, f"{meta['tax_id']}_{prod_name}.prot.fasta")

            with open(in_prot_file_path) as in_file_obj, open(out_prot_file_path, "w") as out_file_obj:
                for rec in SeqIO.parse(in_file_obj, "fasta"):
                    db_name, uniq_id, entry_name = rec.id.split("|")
                    if uniq_id in cds_ids:
                        SeqIO.write([rec], out_file_obj, "fasta")

            source_meta.append({
                "production_name": prod_name,
                "taxonomy_id": meta["tax_id"],
                "cds_fasta": out_cds_file_path,
                "prot_fasta": out_prot_file_path,
                "source": "uniprot"
            })

        with open(args.meta_file, "w") as out_file_obj:
            json.dump(source_meta, out_file_obj)
