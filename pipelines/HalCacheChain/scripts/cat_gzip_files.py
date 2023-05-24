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
"""Concatenate GZIP files."""

from argparse import ArgumentParser
import gzip
import shutil


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("input_file", nargs="+", help="One or more input GZIP files.")
    parser.add_argument(
        "-o", "--output-file", metavar="PATH", help="Output concatenated GZIP file."
    )
    args = parser.parse_args()

    with gzip.open(args.output_file, "wb") as out_file_obj:
        for input_file in args.input_file:
            with gzip.open(input_file, "rb") as in_file_obj:
                shutil.copyfileobj(in_file_obj, out_file_obj)
