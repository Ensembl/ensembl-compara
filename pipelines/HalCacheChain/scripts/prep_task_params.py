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
"""Prepare liftover task parameters."""

from __future__ import annotations
from argparse import ArgumentParser
from pathlib import Path

import pandas as pd

from ensembl.compara.utils.ucsc import load_chrom_sizes_file


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("input_tsv", help="Input parameter TSV file.")
    parser.add_argument("hal_file", help="Input HAL file.")
    parser.add_argument("chrom_sizes_dir", help="Directory of chrom sizes files.")
    parser.add_argument("output_tsv", help="Output prepped parameter TSV file.")
    args = parser.parse_args()

    supported_col_names = [
        "source_genome",
        "source_sequence",
        "source_start",
        "source_end",
        "source_strand",
        "dest_genome",
    ]

    param_df = pd.read_csv(args.input_tsv, sep="\t")
    rel_col_names = param_df.columns[param_df.columns.isin(supported_col_names)]
    param_df = param_df[rel_col_names].drop_duplicates(ignore_index=True)

    genomes = set(param_df["source_genome"]) | set(param_df["dest_genome"])

    chrom_sizes_dir_path = Path(args.chrom_sizes_dir)
    genome_to_chr_sizes = {}
    for genome in genomes:
        chrom_sizes_file_path = chrom_sizes_dir_path / f"{genome}.chrom.sizes"
        genome_to_chr_sizes[genome] = load_chrom_sizes_file(chrom_sizes_file_path)

    known_location_params = {"source_start", "source_end", "source_strand"}
    specified_location_params = set(param_df.columns) & known_location_params

    if "source_sequence" not in param_df.columns:
        liftover_level = "genome"
        if specified_location_params:
            raise ValueError(
                f"cannot set source location parameters ("
                f"{','.join(specified_location_params)}) without 'source_sequence'"
            )
    else:
        if len(specified_location_params) == 0:
            liftover_level = "sequence"
        else:
            liftover_level = "location"

            missing_location_params = known_location_params - specified_location_params
            if missing_location_params:
                raise ValueError(
                    f"cannot set source location parameters ({' and '.join(specified_location_params)})"
                    f" without setting {' and '.join(missing_location_params)}"
                )

    if liftover_level == "genome":
        temp_dfs = []
        for _, row in param_df.iterrows():
            temp_df = pd.DataFrame(
                [
                    (row.source_genome, seq_name)
                    for seq_name in genome_to_chr_sizes[row.source_genome]
                ],
                columns=["source_genome", "source_sequence"],
            )
            temp_df = temp_df.merge(row.to_frame().transpose(), on="source_genome")
            temp_dfs.append(temp_df)
        param_df = pd.concat(temp_dfs)

        param_df["group_level"] = "genome"
        param_df["group_size"] = param_df.apply(
            lambda row: len(genome_to_chr_sizes[row.source_genome]), axis=1
        )
        param_df["group_key"] = param_df.apply(
            lambda row: f"{row.source_genome}|{row.dest_genome}", axis=1
        )

        liftover_level = "sequence"

    if liftover_level in ("genome", "sequence"):
        param_df["source_start"] = 1
        param_df["source_end"] = param_df.apply(
            lambda x: genome_to_chr_sizes[x.source_genome][x.source_sequence], axis=1
        )

    param_df["liftover_level"] = liftover_level

    param_df.to_csv(args.output_tsv, sep="\t", index=False)
