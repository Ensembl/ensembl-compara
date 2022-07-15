#!/usr/bin/env python
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
"""Concatenate the constrained elements from each Genomic Align Block (GAB) into one file for each species
present in the alignment

The coordinates of each constrained element are translated from the GAB coordinate level to the Genome
coordinate level of each species and then they are concatenated into one file per species

Typical usage example:

    $ python concatenate_constrained_elements.py --json_desc gab_ce.txt --out_dir ./out/

"""

import argparse
import json
from typing import Dict

from ensembl.compara.utils import alignment_to_seq_region


def translate_ce_coordinates(json_conf: str) -> Dict:
    """Project each of the constrained elements to the unaligned genomic coordinates in each
    genome/species aligned

    Args:
        json_conf: file storing the list of json files to analyse

    Returns:
        A dictionary of assembly name to constrained element at the genomic coordinate level for the named
        assembly.The constrained element is a list of the type [seq_name, start, end, score, pval, strand]

    """
    result = {}  # type: ignore
    with open(json_conf, 'r') as json_file_handler:
        align_set = json.load(json_file_handler)
        aligned_seqs = align_set["aligned_seq"]
        constrained_elems = align_set["constrained_elems"]

        for aligned_seq in aligned_seqs:
            cigar = aligned_seq["cigar"]
            unaligned_seq_size = int(aligned_seq["dnafrag_end"]) - int(aligned_seq["dnafrag_start"]) + 1
            for constrained_elem in constrained_elems:
                # convert from aligned coordinate to unaligned coordinate

                region = alignment_to_seq_region(cigar, int(constrained_elem["start"]),
                                                 int(constrained_elem["end"]))
                if not region:  # if empty tuple go to the next constrained element
                    continue
                ce_seq_start = region[0]
                ce_seq_end = region[1]
                if int(aligned_seq["dnafrag_strand"]) == -1:  # if negative strand calculate coordinates
                                                              # based on reverse complement
                    seq_start = unaligned_seq_size - ce_seq_end + 1
                    ce_seq_end = unaligned_seq_size - ce_seq_start + 1
                    ce_seq_start = seq_start

                # convert to the genomic coordinate
                ce_genomic_start = ce_seq_start + int(aligned_seq["dnafrag_start"]) - 1
                ce_genomic_end = ce_seq_end + int(aligned_seq["dnafrag_start"]) - 1

                # add constrained elements in the dictionary
                genome_name = aligned_seq["genome_name"]
                if genome_name not in result:
                    result[genome_name] = []
                result[genome_name].append([aligned_seq["dnafrag_name"], ce_genomic_start, ce_genomic_end,
                                            constrained_elem["score"], constrained_elem["p-val"],
                                            aligned_seq["dnafrag_strand"]])
    return result


def save_constrained_elements(constraint_species: dict, out_dir: str) -> None:
    """Save in TSV  format the constraint elements for each species

        The format is the following: <seq name> \t <start> \t <end> \t <score> \t <pval> \t <strand>
        The file name will be prefixed with the name of the assembly and post-fixed with .tsv

    Args:
        constraint_species: Dictionary with key the species and value the list of constraint elements
        out_dir: out directory where the bed files are saved
    """
    for sp, ces in constraint_species.items():
        with open(f"{out_dir}/{sp}.tsv", "w") as bed_file_obj:
            ## add sorting ces
            for ce in ces:
                strand = "+"
                if ce[5] == -1:
                    strand = "-"
                line = f"{ce[0]}\t{ce[1]}\t{ce[2]}\t{ce[3]}\t{ce[4]}\t{strand}\n"
                bed_file_obj.write(line)


def main(params: argparse.Namespace) -> None:
    """ Main function of the script

    Args:
        params argparse.Namespace parameters provided by the user.
    """
    # concatenate the constraints elements per species
    with open(params.json_desc) as file_obj:
        species = {}  # type: ignore
        for json_file in file_obj:
            json_file = json_file.rstrip()
            sp_constrained = translate_ce_coordinates(json_file)
            for sp, ces in sp_constrained.items():
                if sp not in species:
                    species[sp] = []
                species[sp] = species[sp] + ces
        save_constrained_elements(species, params.out_dir)


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Process some integers.")
    parser.add_argument("--json_desc", type=str, required=True, help="File listing the path to all the "
                                               "align set json file for a given alignment")
    parser.add_argument("--out_dir", type=str, required=True, help="out directory storing all the  "
                                               "constrained element files concatenated at the species level")
    args = parser.parse_args()
    main(args)
