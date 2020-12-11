"""
Runnable to split a fasta file into parts. This is defined either by the number of
sequences in each part (num_seqs) or by the desired number of parts (num_parts).

By default, the output directory will be derived from the input file name (replacing
`.fa` or `.fasta` with `.split`)

"""
import os
import re
import sys
from Bio import SeqIO
import eHive

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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

class SplitFasta(eHive.BaseRunnable):
    """Split a FastA file into pieces"""

    def param_defaults(self):
        """set default parameters"""
        return {
            'num_seqs'  : False,
            'num_parts' : False
        }


    def fetch_input(self):
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
            num_seqs = int(len(fasta_records) / num_parts)

        self.param('fasta_records', fasta_records)
        self.param('num_seqs', num_seqs)

    def run(self):
        """create output directory and set file prefix"""
        if not self.param_exists('out_dir'):
            out_dir = re.sub('\..+$', '.split', self.param('fasta_name'))
            self.param('out_dir', out_dir)

        out_dir = self.param_required('out_dir')
        if not os.path.exists(out_dir):
            os.mkdir(out_dir)

        if not self.param_exists('file_prefix'):
            file_prefix = os.path.basename(self.param('fasta_name')).split('.')[0]
            self.param('file_prefix', file_prefix)


    def write_output(self):
        """write fasta records to multiple files"""
        fasta_records = self.param('fasta_records')
        file_prefix = self.param('file_prefix')
        num_seqs = self.param('num_seqs')
        out_dir = self.param('out_dir')

        records_written, files_written = 0, 1
        out_file = open(f"{out_dir}/{file_prefix}.{files_written}.fasta", 'w')
        for fasta_record in fasta_records:
            if records_written > 0 and records_written % num_seqs == 0:
                out_file.close()
                files_written += 1
                out_file = open(f"{out_dir}/{file_prefix}.{files_written}.fasta", 'w')

            out_file.write(f">{fasta_record[0]}\n{fasta_record[1]}\n")
            records_written += 1
