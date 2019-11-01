#!/homes/carlac/anaconda_ete/bin/python

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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

import sys, os, argparse
from ete3 import Tree

parser = argparse.ArgumentParser()
parser.add_argument('-t', '--tree')
parser.add_argument('-bl', '--branch_lengths', action='store_true')
parser.add_argument('-v', '--verbose', action='store_true')
opts = parser.parse_args(sys.argv[1:])

if not os.path.isfile(opts.tree):
	sys.stderr.write("File %s not found", opts.tree)
	sys.exit(1)
	 
t = Tree(opts.tree)
if opts.verbose == True:
	orig_root = t.get_tree_root()
	sys.stderr.write("ORIGINAL TREE:\n" + orig_root.write(format=9) + "\n\n\n")

# intial unroot
t.unroot()	
# reroot by midpoint to force unrooting later
midpoint = t.get_midpoint_outgroup()
t.set_outgroup(midpoint)

if opts.verbose == True:
	sys.stderr.write("MIDPOINT ROOTING:\n" + t.write(format=9) + "\n\n\n")

# final forced unrooting of tree to be absolutely sure	
t.unroot()

if opts.verbose == True:
	sys.stderr.write("UNROOTED:\n" + t.write(format=9) + "\n\n\n")
	
if opts.branch_lengths == True:
	print(t.write(format=5))
else:
	print(t.write(format=9))