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

"""Script to root a tree given an outgroup"""

import argparse
import os
import sys

from ete3 import Tree

parser = argparse.ArgumentParser()
parser.add_argument('-t', '--tree')
parser.add_argument('-o', '--outgroup')
opts = parser.parse_args(sys.argv[1:])

# check arguments
if not os.path.isfile(opts.tree):
    sys.stderr.write(f"File {opts.tree} not found")
    sys.exit(1)

try:
    opts.outgroup
except NameError:
    sys.stderr.write("Outgroup must be defined (--outgroup)")
    sys.exit(1)


t = Tree(opts.tree)
t.set_outgroup(opts.outgroup)
print(t.get_tree_root().write(format=5))
