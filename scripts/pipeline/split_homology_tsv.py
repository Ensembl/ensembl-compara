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
"""Split input homology TSV file by genome."""

from argparse import ArgumentParser
from collections import defaultdict
from contextlib import ExitStack
import csv
import json
import logging
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory

from ensembl.compara.utils.csv import UnquotedUnixTab


def _open_output_gdb_hom_tsv(context_stack, base_dir_path, genome_name):
    """Open temp genome-specific homology TSV file for output.

    Args:
        context_stack: An object for handling with-statement contexts.
        base_dir_path: Path of output base directory.
        genome_name: Name of genome for which the output homology TSV file should be opened.

    Returns:
        Genome-specific homology TSV file object, opened in write mode.
    """
    tmp_gdb_file_path = base_dir_path / f"{genome_name}.tsv"
    return context_stack.enter_context(open(tmp_gdb_file_path, mode="w", encoding="utf-8", newline=""))


if __name__ == "__main__":

    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--input_file", required=True, help="Input homology TSV file path.")
    parser.add_argument("--species_path_file", required=True, help="Species-path mapping JSON file.")
    parser.add_argument("--output_base_dir", required=True, help="Output base directory path.")
    parser.add_argument("--dataflow_file", help="Optional dataflow file.")

    args = parser.parse_args()

    in_file_path = Path(args.input_file)
    out_base_dir_path = Path(args.output_base_dir)

    logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

    logging.info("Processing homology TSV file '%s' ...", in_file_path)

    logging.info("Loading species-path mapping from '%s' ...", args.species_path_file)
    species_path_map = {}
    with open(args.species_path_file, encoding="utf-8") as in_file_obj:
        data = json.load(in_file_obj)
        for gdb_name, species_path in data.items():
            species_path = Path(species_path)
            if len(species_path.parts) == 0:
                raise ValueError(f"genome {gdb_name} has empty species path")
            if any(x in ("", ".", "..") for x in species_path.parts):
                raise ValueError(f"genome {gdb_name} has disallowed species path")
            species_path_map[gdb_name] = species_path

    hom_tsv_by_genome = {}
    out_base_dir_path.mkdir(mode=0o775, parents=True, exist_ok=True)
    with TemporaryDirectory(dir=out_base_dir_path, prefix=".tmp_hom_tsv_") as tmp_dir:
        tmp_dir_path = Path(tmp_dir)

        logging.info("Splitting homology TSV by genome ...")
        exp_line_counts: defaultdict[str, int] = defaultdict(int)
        writers_by_genome = {}   # type: ignore
        tmp_tsv_by_genome = {}
        with ExitStack() as stack:
            in_file_obj = stack.enter_context(open(in_file_path, encoding="utf-8", newline=""))
            reader = csv.DictReader(in_file_obj, dialect=UnquotedUnixTab)

            for row in reader:
                gdb_name = row["species"]
                try:
                    writer = writers_by_genome[gdb_name]
                except KeyError:
                    logging.info("Opening homology TSV for genome '%s' ...", gdb_name)
                    out_file_obj = _open_output_gdb_hom_tsv(
                        stack,
                        tmp_dir_path,
                        gdb_name,
                    )
                    species_path = species_path_map[gdb_name]
                    hom_tsv_by_genome[gdb_name] = out_base_dir_path / species_path / in_file_path.name
                    tmp_tsv_by_genome[gdb_name] = Path(out_file_obj.name)
                    writer = csv.writer(out_file_obj, dialect=UnquotedUnixTab)
                    writers_by_genome[gdb_name] = writer
                exp_line_counts[gdb_name] += 1
                writer.writerow(row.values())

                reciprocal = [
                    row["homology_gene_stable_id"],
                    row["homology_protein_stable_id"],
                    row["homology_species"],
                    row["homology_identity"],
                    row["homology_type"],
                    row["gene_stable_id"],
                    row["protein_stable_id"],
                    row["species"],
                    row["identity"],
                    row["dn"],
                    row["ds"],
                    row["goc_score"],
                    row["wga_coverage"],
                    row["is_high_confidence"],
                    row["homology_id"],
                ]

                hom_gdb_name = row["homology_species"]
                try:
                    writer = writers_by_genome[hom_gdb_name]
                except KeyError:
                    logging.info("Opening homology TSV for genome '%s' ...", hom_gdb_name)
                    out_file_obj = _open_output_gdb_hom_tsv(
                        stack,
                        tmp_dir_path,
                        hom_gdb_name,
                    )
                    species_path = species_path_map[hom_gdb_name]
                    hom_tsv_by_genome[hom_gdb_name] = out_base_dir_path / species_path / in_file_path.name
                    tmp_tsv_by_genome[hom_gdb_name] = Path(out_file_obj.name)
                    writer = csv.writer(out_file_obj, dialect=UnquotedUnixTab)
                    writers_by_genome[hom_gdb_name] = writer
                exp_line_counts[hom_gdb_name] += 1
                writer.writerow(reciprocal)

        logging.info("Checking homology TSV line counts ...")
        for gdb_name, tmp_hom_tsv_path in tmp_tsv_by_genome.items():
            exp_line_count = exp_line_counts[gdb_name]
            logging.info("Checking line count of homology TSV of genome '%s' ...", gdb_name)
            cmd_args = ["wc", "-l", str(tmp_hom_tsv_path)]
            output = subprocess.check_output(cmd_args, text=True)
            first_line, *_ignored_lines = output.splitlines()
            first_field, *_ignored_fields = first_line.split()
            obs_line_count = int(first_field)
            if obs_line_count != exp_line_count:
                raise ValueError(
                    f"line-count mismatch in homology TSV of genome '{gdb_name}':"
                    f" {obs_line_count} (observed) vs {exp_line_count} (expected)"
                )

        logging.info("Writing homology TSV files to output directory ...")
        for gdb_name, hom_tsv_path in hom_tsv_by_genome.items():
            logging.info("Writing output homology TSV of genome '%s' ...", gdb_name)
            tmp_tsv_path = tmp_tsv_by_genome[gdb_name]
            hom_tsv_path.parent.mkdir(mode=0o775, parents=True, exist_ok=True)
            shutil.move(tmp_tsv_path, hom_tsv_path)

    if args.dataflow_file:
        dataflow_file_path = Path(args.dataflow_file)

        dataflow_branch = 1
        dataflow_events = []
        for gdb_name in sorted(hom_tsv_by_genome):
            hom_tsv_file_dir = str(hom_tsv_by_genome[gdb_name].parent)
            hom_tsv_file_path = str(hom_tsv_by_genome[gdb_name])
            dataflow_json = json.dumps(
                {
                    "gdb_name": gdb_name,
                    "homology_tab_file_dir": hom_tsv_file_dir,
                    "homology_tab_file_path": hom_tsv_file_path,
                }
            )
            dataflow_events.append(f"{dataflow_branch} {dataflow_json}")

        dataflow_file_path.parent.mkdir(mode=0o775, parents=True, exist_ok=True)
        with open(dataflow_file_path, "w", encoding="utf-8") as out_file_obj:
            for dataflow_event in dataflow_events:
                print(dataflow_event, file=out_file_obj)

    logging.info("Done.")
