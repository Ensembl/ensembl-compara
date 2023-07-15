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
import logging
import os
from pathlib import Path
import re
import string
from tarfile import TarFile
from tempfile import TemporaryDirectory
from typing import Dict, Union

from Bio import SeqIO
import pandas as pd


def generate_production_name(species_name: str) -> str:
    """Returns a production name generated from the given species name."""
    unqualified_species_name = re.sub(r"\(.+$", "", species_name).rstrip()
    underscored_species_name = re.sub(r"\s+", "_", unqualified_species_name)
    lowercased_species_name = underscored_species_name.lower()
    return re.sub("[^a-z0-9_]", "", lowercased_species_name)


def parse_qfo_proteome_table(qfo_readme_file: Union[Path, str]) -> pd.DataFrame:
    """Parse table in QfO reference proteome README file.

    Args:
        qfo_readme_file: Input QfO reference proteome README file.

    Returns:
        A pandas DataFrame containing QfO reference proteome metadata.

    """
    # This dict holds key meta-info about the format of the table in the QfO README file. By default, the
    # table format meta-info of the most recent known release is used, so it should be possible to use this
    # script on subsequent releases, provided that the table format has not changed since the most recent
    # release included here. If there have been changes to the table format, you may need to update this dict
    # with the new header line and updated sanitised column names. (Why sanitise the column names? Keeping
    # them consistent, valid as Python identifiers etc. makes it easier to handle the proteome metadata.)
    release_meta = {
        "2015_to_2020": {
            "header": "Proteome_ID Tax_ID  OSCODE     #(1)    #(2)    #(3)  Species Name",
            "columns": [
                "proteome_id",
                "tax_id",
                "oscode",
                "num_canonical",
                "num_additional",
                "num_gene2acc",
                "species_name"
            ],
            "releases": ["2015_04", "2016_04", "2017_04", "2018_04", "2019_04"]
        },
        "2020_to_date": {
            "header": "Proteome_ID     Tax_ID  OSCODE  SUPERREGNUM     #(1)    #(2)    #(3)    Species_Name",
            "columns": [
                "proteome_id",
                "tax_id",
                "oscode",
                "superregnum",
                "num_canonical",
                "num_additional",
                "num_gene2acc",
                "species_name"
            ],
            "releases": ["2020_04", "2021_03", "2022_02"]
        },
    }

    release_to_header: Dict = {}
    release_to_columns: Dict = {}
    for meta in release_meta.values():
        release_to_header.update(dict.fromkeys(meta["releases"], meta["header"]))
        release_to_columns.update(dict.fromkeys(meta["releases"], meta["columns"]))

    # Release '2020_04' README contains a table with
    # post-2020 columns underneath a pre-2020 header.
    release_to_header["2020_04"] = release_meta["2015_to_2020"]["header"]

    release_re = re.compile(r"Release (?P<release>[0-9]{4}_[0-9]{2}), [0-9]{2}-[A-Z][a-z]+-[0-9]{4}")

    release = None
    table_lines = []
    with open(qfo_readme_file) as file_obj:
        exp_header_line = None
        reading_table = False
        for line in file_obj:
            line = line.rstrip("\n")
            if not reading_table:
                release_line_match = release_re.fullmatch(line)
                if release_line_match:
                    release = release_line_match["release"]
                    try:
                        exp_header_line = release_to_header[release]
                    except KeyError:
                        release = max(release_to_header.keys())
                        exp_header_line = release_to_header[release]
                elif exp_header_line and line == exp_header_line:
                    reading_table = True
                    continue
            else:
                if not line:
                    break
                table_lines.append(line)

    if not table_lines:
        raise RuntimeError(f"failed to extract QfO proteome table from '{qfo_readme_file}'")

    max_split = len(release_to_columns[release]) - 1
    rows = [x.split(maxsplit=max_split) for x in table_lines]
    proteome_meta = pd.DataFrame(rows, columns=release_to_columns[release])

    prod_names = proteome_meta["species_name"].apply(generate_production_name)
    if prod_names.duplicated().any():
        dup_prod_names = set(prod_names[prod_names.duplicated()])
        raise ValueError(f"duplicate species production name(s): {','.join(dup_prod_names)}")
    proteome_meta["production_name"] = prod_names

    # With consistently ordered proteome metadata,
    # it will be easier to track meaningful changes.
    proteome_meta.sort_values(by="production_name", inplace=True)

    return proteome_meta


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Prepare QfO reference proteome files for processing.")
    parser.add_argument("qfo_archive",
                        help="Input QfO archive file.")
    parser.add_argument("meta_file",
                        help="Output JSON file of proteome metadata.")
    parser.add_argument("output_dir",
                        help="Directory to which proteome data will be output.")
    parser.add_argument("--disallow-ambiguity-codes", action="store_true",
                        help="Filter out CDS FASTA records containing symbols"
                             " other than 'A', 'C', 'G', 'T' or 'N'.")
    parser.add_argument("--skip-invalid-cds", action="store_true",
                        help="Skip CDS FASTA records with invalid DNA sequence.")
    parser.add_argument("--stats-file", metavar="PATH",
                        help="Output TSV file of proteome prep stats.")

    args = parser.parse_args()

    valid_cds_symbols = set("ABCDGHKMNRSTVWY"
                            "abcdghkmnrstvwy")
    strict_cds_symbols = set("ACGTN"
                             "acgtn")
    valid_aa_symbols = set(string.ascii_letters)

    with TarFile.open(args.qfo_archive) as tar_file, TemporaryDirectory() as tmp_dir:

        tar_file.extract("README", tmp_dir)
        readme_file = os.path.join(tmp_dir, "README")
        uniprot_meta = parse_qfo_proteome_table(readme_file)

        fa_name_to_tar_info = {}
        for tar_info in tar_file.getmembers():
            if tar_info.isfile() and tar_info.name.endswith(".fasta"):
                fa_name = os.path.basename(tar_info.name)
                fa_name_to_tar_info[fa_name] = tar_info

        out_dir = os.path.abspath(args.output_dir)
        os.makedirs(out_dir, exist_ok=True)

        prep_stats = []
        source_meta = []
        for row in uniprot_meta.itertuples():
            exp_cds_fa_name = f"{row.proteome_id}_{row.tax_id}_DNA.fasta"
            cds_member = fa_name_to_tar_info[exp_cds_fa_name]
            exp_prot_fa_name = f"{row.proteome_id}_{row.tax_id}.fasta"
            prot_member = fa_name_to_tar_info[exp_prot_fa_name]
            tar_file.extractall(tmp_dir, [cds_member, prot_member])

            in_cds_file_path = os.path.join(tmp_dir, cds_member.name)
            out_cds_file_path = os.path.join(out_dir, f"{row.tax_id}_{row.production_name}.cds.fasta")

            cds_ids = set()
            num_part_ambig_cds = 0
            num_invalid_cds = 0
            skipped_ambig_cds_ids = set()
            skipped_invalid_cds_ids = set()
            with open(in_cds_file_path) as in_file_obj, open(out_cds_file_path, "w") as out_file_obj:
                for rec in SeqIO.parse(in_file_obj, "fasta"):
                    db_name, uniq_id, entry_name = rec.id.split("|")
                    seq_symbols = set(str(rec.seq))

                    issues = []
                    action = "keeping"
                    if (seq_symbols & valid_cds_symbols) - strict_cds_symbols:
                        if args.disallow_ambiguity_codes:
                            skipped_ambig_cds_ids.add(uniq_id)
                            issues.append("disallowed ambiguity codes")
                            action = "skipping"
                        num_part_ambig_cds += 1

                    if seq_symbols - valid_cds_symbols:
                        if args.skip_invalid_cds:
                            skipped_invalid_cds_ids.add(uniq_id)
                            issues.append("invalid sequence")
                            action = "skipping"
                        num_invalid_cds += 1

                    if issues:
                        logging.warning("FASTA record '%s' in '%s' has %s, %s",
                                        rec.id, cds_member.name, " and ".join(issues), action)
                        if action == "skipping":
                            continue

                    SeqIO.write([rec], out_file_obj, "fasta")
                    cds_ids.add(uniq_id)

            skipped_cds_ids = skipped_ambig_cds_ids | skipped_invalid_cds_ids
            os.remove(in_cds_file_path)

            in_prot_file_path = os.path.join(tmp_dir, prot_member.name)
            out_prot_file_path = os.path.join(out_dir, f"{row.tax_id}_{row.production_name}.prot.fasta")

            num_canonical = 0
            num_without_cds = 0
            num_prepped = 0
            with open(in_prot_file_path) as in_file_obj, open(out_prot_file_path, "w") as out_file_obj:
                for rec in SeqIO.parse(in_file_obj, "fasta"):
                    db_name, uniq_id, entry_name = rec.id.split("|")
                    if not set(str(rec.seq)) <= valid_aa_symbols:
                        raise ValueError(
                            f"FASTA record '{rec.id}' in '{prot_member.name}' has invalid AA sequence")
                    if uniq_id in cds_ids:
                        SeqIO.write([rec], out_file_obj, "fasta")
                        num_prepped += 1
                    elif uniq_id not in skipped_cds_ids:
                        logging.warning("FASTA record '%s' in '%s' has no CDS, skipping",
                                        rec.id, cds_member.name)
                        num_without_cds += 1
                    num_canonical += 1
            os.remove(in_prot_file_path)

            source_meta.append({
                "production_name": row.production_name,
                "taxonomy_id": int(row.tax_id),
                "cds_fasta": out_cds_file_path,
                "prot_fasta": out_prot_file_path,
                "source": "uniprot"
            })

            prep_stats.append({
                "production_name": row.production_name,
                "num_canonical": num_canonical,
                "num_part_ambig_cds": num_part_ambig_cds,
                "num_invalid_cds": num_invalid_cds,
                "num_skipped_cds": len(skipped_cds_ids),
                "num_without_cds": num_without_cds,
                "num_prepped": num_prepped
            })

        with open(args.meta_file, "w") as out_file_obj:
            json.dump(source_meta, out_file_obj, indent=4)

        if args.stats_file:
            stats_df = pd.DataFrame(prep_stats)
            stats_df.sort_values(by="production_name", inplace=True)
            stats_df.to_csv(args.stats_file, sep="\t", index=False)
