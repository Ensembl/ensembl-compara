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

"""Script to unroot a tree"""

import argparse
import os
import sys

from ete3 import Tree

parser = argparse.ArgumentParser()
parser.add_argument('-t', '--tree')
parser.add_argument('-bl', '--branch_lengths', action='store_true')
parser.add_argument('-v', '--verbose', action='store_true')
opts = parser.parse_args(sys.argv[1:])

if not os.path.isfile(opts.tree):
    sys.stderr.write("File {0} not found".format(opts.tree))
    sys.exit(1)

t = Tree(opts.tree)
if opts.verbose:
    orig_root = t.get_tree_root()
    sys.stderr.write("ORIGINAL TREE:\n" + orig_root.write(format=9) + "\n\n\n")

# intial unroot
t.unroot()

# reroot by midpoint to force unrooting later
midpoint = t.get_midpoint_outgroup()
t.set_outgroup(midpoint)

if opts.verbose:
    sys.stderr.write("MIDPOINT ROOTING:\n" + t.write(format=9) + "\n\n\n")

# forced unrooting of tree to be absolutely sure
while len(t.get_children()) == 2:
    t.unroot()
    midpoint = t.get_midpoint_outgroup()
    t.set_outgroup(midpoint)
    t.unroot()

if opts.verbose:
    sys.stderr.write("UNROOTED:\n" + t.write(format=9) + "\n\n\n")

if opts.branch_lengths:
    print(t.write(format=5))
else:
    print(t.write(format=9))
