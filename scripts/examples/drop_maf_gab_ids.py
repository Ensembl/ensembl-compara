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
"""Preprocess a LastZ MAF file to remove GenomicAlignBlock identifiers."""

from argparse import ArgumentParser
from collections.abc import Iterator
import re

from Bio.AlignIO.MafIO import MafIterator, MafWriter


class ComparaMafPreprocessor(Iterator):
    """Class to preprocess Compara MAF files."""

    def __init__(self, stream):
        self.stream = stream
        self.cached_line = None

    def __next__(self):
        if self.cached_line:
            line = self.cached_line
            self.cached_line = None
        else:
            line = next(self.stream)
            if line.startswith("a"):
                comment_regex = re.compile(r"#[^\r\n]*")
                line = comment_regex.sub("", line)
                next_line = next(self.stream)
                name_value_pair_regex = re.compile(r"\s*(\S+=\S+)(\s+\S+=\S+)*\s*")
                if name_value_pair_regex.fullmatch(next_line):
                    line = line.rstrip() + next_line
                else:
                    self.cached_line = next_line
        return line


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)

    parser.add_argument("input_maf", metavar="PATH", help="Input MAF file.")
    parser.add_argument("output_maf", metavar="PATH", help="Output MAF file.")

    args = parser.parse_args()

    with open(args.output_maf, mode="w", encoding="utf-8") as out_file_obj:
        maf_writer = MafWriter(out_file_obj)
        maf_writer.write_header()
        with open(args.input_maf, encoding="utf-8") as in_file_obj:
            preprocessed_lines = ComparaMafPreprocessor(in_file_obj)
            for maf_block in MafIterator(preprocessed_lines):
                maf_writer.write_alignment(maf_block)
