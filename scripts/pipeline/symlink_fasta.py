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

"""Script to create and optionally cleanup symlinks in a central location"""

import argparse
import glob
import os
import re
import sys

from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('-c', '--cleanup_symlinks', action='store_true')
parser.add_argument('-s', '--symlink_dir')
group = parser.add_mutually_exclusive_group(required=True)
# Only one of target_dir or target_file can be specified
group.add_argument('-d', '--target_dir')
group.add_argument('-t', '--target_file')
opts = parser.parse_args(sys.argv[1:])

target_dir = opts.target_dir
symlink_dir = opts.symlink_dir
target_file = opts.target_file

# Create symlink directory if doesn't exist
Path(symlink_dir).mkdir(parents=True, exist_ok=True)

# Clean up the broken symlinks - these should be due to genome retirement
if opts.cleanup_symlinks:
    for link in glob.glob(os.path.join(symlink_dir, '**/*.fasta'), recursive=True):
        if not os.path.exists(os.readlink(link)):
            print('Broken symlink: {0} to be removed'.format(link))
            os.remove(link)

# Collect all the genome fasta files and symlink them
if target_dir:
    for fasta_file in glob.glob(os.path.join(target_dir, '**/*.fasta'), recursive=True):
        # Skip split fasta files
        if re.search(r'split\b', fasta_file):
            continue
        file_prefix = os.path.basename(fasta_file)
        symlink_path = os.path.join(symlink_dir, file_prefix)
        if not os.path.exists(symlink_path):
            print('New symlink: {0} created for target: {1}'.format(symlink_path, fasta_file))
            os.symlink(fasta_file, symlink_path)
else:
    file_prefix = os.path.basename(target_file)
    symlink_path = os.path.join(symlink_dir, file_prefix)
    if not os.path.exists(symlink_path):
        print('New symlink: {0} created for target: {1}'.format(symlink_path, target_file))
        os.symlink(target_file, symlink_path)
