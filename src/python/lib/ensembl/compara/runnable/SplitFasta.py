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

"""Runnable to split a fasta file into parts.

This runnable splits a fasta file into parts defined either by the number of sequences in each part
(num_seqs) or by the desired number of parts (num_parts).

By default, the output directory will be derived from the input file name (replacing
`.fa` or `.fasta` with `.split`)

"""

import os
import sys
from typing import Dict

from Bio import SeqIO

import eHive

class SplitFasta(eHive.BaseRunnable):
    """Splits a fasta file into pieces"""

    def param_defaults(self) -> Dict[str, bool]:
        """set default parameters"""
        return {
            'num_seqs'  : False,
            'num_parts' : False
        }


    def fetch_input(self) -> None:
        """grab fasta and parse"""
        fasta_file = self.param_required('fasta_name')

        num_seqs = self.param('num_seqs')
        num_parts = self.param('num_parts')

        if not num_seqs and not num_parts:
            self.warning("'num_seqs' or 'num_parts' must be defined")
            sys.exit(1)

        fasta_records = []
        for record in SeqIO.parse(fasta_file, "fasta"):
            fasta_records.append((record.id, record.seq))

        if num_parts:
            if num_parts > len(fasta_records):
                warn = (f"'num_parts' ({num_parts}) is larger than the number of records in the file"
                        f" ({len(fasta_records)}) - printing a single record in each file")
                self.warning(warn)
                num_parts = len(fasta_records)
            num_seqs = int(len(fasta_records) / num_parts)

        self.param('fasta_records', fasta_records)
        self.param('num_seqs', num_seqs)

    def run(self) -> None:
        """create output directory and set file prefix"""
        if not self.param_exists('out_dir'):
            out_dir = os.path.splitext(self.param('fasta_name'))[0] + ".split"
            self.param('out_dir', out_dir)

        out_dir = self.param_required('out_dir')
        if not os.path.exists(out_dir):
            os.mkdir(out_dir)

        if not self.param_exists('file_prefix'):
            file_prefix = os.path.splitext(os.path.basename(self.param('fasta_name')))[0]
            self.param('file_prefix', file_prefix)


    def write_output(self):
        """write fasta records to multiple files"""
        fasta_records = self.param('fasta_records')
        file_prefix = self.param('file_prefix')
        num_seqs = self.param('num_seqs')
        out_dir = self.param('out_dir')

        files_written = 1
        for seq_idx in range(0, len(fasta_records), num_seqs):
            dst_file = os.path.join(out_dir, f"{file_prefix}.{files_written}.fasta")
            with open(dst_file, 'w') as out_file:
                for fasta_record in fasta_records[seq_idx:seq_idx+num_seqs]:
                    out_file.write(f">{fasta_record[0]}\n{fasta_record[1]}\n")
            files_written += 1
