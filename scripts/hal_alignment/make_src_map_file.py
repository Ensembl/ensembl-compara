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
"""Utility script to make MAF src mapping TSV file."""

import argparse
import csv
import os
import re
import subprocess
from tempfile import TemporaryDirectory

from sqlalchemy import create_engine, text


def main() -> None:
    """Main function of script."""
    # pylint: disable=too-many-branches

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hal-genome", help="HAL genome.")
    parser.add_argument("--hal-file", help="Input HAL file.")
    parser.add_argument("--assembly-accession", help="GenBank assembly accession.")
    parser.add_argument("--metadata-url", help="URL of metadata database.")
    parser.add_argument("-o", "--output-tsv", help="Output two-column tab-separated src mapping file.")
    args = parser.parse_args()

    metadata_engine = create_engine(args.metadata_url)

    params = {"assembly_accession": args.assembly_accession}

    assembly_query = text(
        """
        SELECT assembly_uuid
        FROM assembly
        WHERE assembly.accession = :assembly_accession;
    """
    )

    with metadata_engine.connect() as conn:
        assembly_uuid = conn.execute(assembly_query, params).scalar_one()

    sequence_query = text(
        """
        SELECT assembly_sequence.name, length, md5
        FROM assembly
        JOIN assembly_sequence USING (assembly_id)
        WHERE assembly.accession = :assembly_accession;
    """
    )

    meta_seqs_by_sum = {}
    with metadata_engine.connect() as conn:
        for seq_name, length, md5sum in conn.execute(sequence_query, params):
            seq_key = (md5sum, length)
            if seq_key in meta_seqs_by_sum:
                raise ValueError(f"clashing sequence key: {seq_key}")
            meta_seqs_by_sum[seq_key] = seq_name

    hal_seqs_by_sum = {}
    with TemporaryDirectory() as tmp_dir:

        tmp_fa_file_path = os.path.join(tmp_dir, "temp.fa")
        cmd1_args = [
            "/hps/software/users/ensembl/compara/shared/build/cactus/3.0.0/local/bin/hal2fasta",
            args.hal_file,
            args.hal_genome,
            "--outFaPath",
            tmp_fa_file_path,
        ]
        subprocess.run(cmd1_args, check=True)

        tmp_dict_file_path = os.path.join(tmp_dir, "temp.dict")
        cmd2_args = [
            "picard",
            "CreateSequenceDictionary",
            f"R={tmp_fa_file_path}",
            f"O={tmp_dict_file_path}",
        ]
        subprocess.run(cmd2_args, check=True)

        # SAM header field regex from https://samtools.github.io/hts-specs/SAMv1.pdf
        sam_header_field_re = re.compile("(?P<tag>[A-Za-z][A-Za-z0-9]):(?P<value>[ -~]+)")

        with open(tmp_dict_file_path, encoding="utf-8") as in_file_obj:
            for line in in_file_obj:
                if line.startswith("@SQ"):
                    fields = line.rstrip("\n").split("\t")
                    seq_meta = {}
                    for field in fields[1:]:
                        if match := sam_header_field_re.fullmatch(field):
                            seq_meta[match["tag"]] = match["value"]
                    seq_key = (seq_meta["M5"], int(seq_meta["LN"]))
                    if seq_key in hal_seqs_by_sum:
                        raise ValueError(f"clashing sequence key: {seq_key}")
                    hal_seqs_by_sum[seq_key] = seq_meta["SN"]

        comm_seq_keys = hal_seqs_by_sum.keys() & meta_seqs_by_sum.keys()

        seq_id_map = {}
        for seq_key in comm_seq_keys:
            hal_seq_id = hal_seqs_by_sum[seq_key]
            meta_seq_id = meta_seqs_by_sum[seq_key]
            seq_id_map[hal_seq_id] = meta_seq_id

        meta_only_seq_keys = meta_seqs_by_sum.keys() - hal_seqs_by_sum.keys()
        hal_only_seq_keys = hal_seqs_by_sum.keys() - meta_seqs_by_sum.keys()

        if hal_only_seq_keys and meta_only_seq_keys:
            meta_seqs_by_length = {}
            for md5sum, length in meta_only_seq_keys:
                if length in meta_seqs_by_length:
                    raise ValueError(f"clashing sequence length: {length}")
                meta_seqs_by_length[length] = meta_seqs_by_sum[(md5sum, length)]

            hal_seqs_by_length = {}
            for md5sum, length in hal_only_seq_keys:
                if length in hal_seqs_by_length:
                    raise ValueError(f"clashing sequence length: {length}")
                hal_seqs_by_length[length] = hal_seqs_by_sum[(md5sum, length)]

            comm_seq_lengths = hal_seqs_by_length.keys() & meta_seqs_by_length.keys()
            for seq_length in comm_seq_lengths:
                hal_seq_id = hal_seqs_by_length[seq_length]
                meta_seq_id = meta_seqs_by_length[seq_length]
                seq_id_map[hal_seq_id] = meta_seq_id

        if not seq_id_map:
            raise ValueError(
                f"no common sequence keys found for HAL genome {args.hal_genome}"
                f" and assembly accession {args.assembly_accession}"
            )

        with open(args.output_tsv, mode="w", encoding="utf-8", newline="") as out_file_obj:
            writer = csv.writer(out_file_obj, delimiter="\t", lineterminator="\n")
            for hal_seq_id, meta_seq_id in sorted(seq_id_map.items()):
                writer.writerow([f"{args.hal_genome}.{hal_seq_id}", f"{assembly_uuid}.{meta_seq_id}"])


if __name__ == "__main__":
    main()
