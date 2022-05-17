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
"""
Script for collating per-genome BUSCO cDNA results.
"""

import argparse
from collections import defaultdict, OrderedDict
from os import path
from typing import Dict, List, Tuple

import pandas as pd
from Bio import SeqIO
from Bio.SeqRecord import SeqRecord

# Parse command line arguments:
parser = argparse.ArgumentParser(
    description='Filter for longest BUSCO isoform.')
parser.add_argument(
    '-i', metavar='input', type=str, help="Input fofn.")
parser.add_argument(
    '-l', metavar='genes', type=str, help="List of busco genes.")
parser.add_argument(
    '-o', metavar='output', type=str, help="Output directory.", default="per_gene")
parser.add_argument(
    '-s', metavar='stats', type=str, help="Output stats TSV.")


def load_sequences(infile: str) -> Tuple[Dict[str, List[SeqRecord]], int]:
    """
    Load sequences from fasta files and filter out duplicates.
    """
    lgenes = defaultdict(list)
    with open(infile) as handle:
        for record in SeqIO.parse(handle, "fasta"):
            gene = str(record.id).split("_", maxsplit=1)[0]
            lgenes[gene].append(record)
    filtered = {}
    lduplicates = 0
    for gene, records in lgenes.items():
        if len(records) > 1:
            lduplicates += 1
        else:
            filtered[gene] = records[0]
    return filtered, lduplicates


if __name__ == '__main__':
    args = parser.parse_args()

    all_genes = pd.read_csv(args.l, sep="\t")
    with open(args.i) as x:
        seq_files = [y.strip() for y in x.readlines()]

    taxa = []
    dups = []
    usable = []
    per_gene = defaultdict(list)
    for seq_file in seq_files:
        genes, duplicates = load_sequences(seq_file)
        taxon = path.basename(seq_file).rsplit(".", maxsplit=1)[0]
        for g, s in genes.items():
            s.id = taxon        # type: ignore
            s.description = ""  # type: ignore
            per_gene[g].append(s)
        taxa.append(taxon)
        dups.append(duplicates)
        usable.append(len(genes))

    stat_data = OrderedDict([('Taxa', taxa), ('Genes', usable), ('Duplicates', dups)])
    stat_df = pd.DataFrame(stat_data)
    stat_df["SetGenes"] = len(all_genes.Gene)
    stat_df["UsablePercent"] = (stat_df.Genes * 100) / stat_df.SetGenes
    stat_df.to_csv(args.s, sep="\t", index=False)

    # Dump per-gene cDNAs:
    for g, s in per_gene.items():
        with open(path.join(args.o, f"gene_cdna_{g}.fas"), "w") as output_handle:
            SeqIO.write(s, output_handle, "fasta")

        ts = []
        for x in s:     # type: ignore
            y = x.translate()   # type: ignore
            y.id = x.id     # type: ignore
            y.description = ""
            ts.append(y)

        with open(path.join(args.o, f"gene_prot_{g}.fas"), "w") as output_handle:
            SeqIO.write(ts, output_handle, "fasta")
