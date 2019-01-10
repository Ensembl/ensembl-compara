#!/homes/carlac/anaconda_ete/bin/python
import sys, os, argparse
from ete3 import Tree

parser = argparse.ArgumentParser()
parser.add_argument('-t', '--tree')
parser.add_argument('-o', '--outgroup')
opts = parser.parse_args(sys.argv[1:])

# check arguments
if not os.path.isfile(opts.tree):
	sys.stderr.write("File %s not found", opts.tree)
	sys.exit(1)

try:
	opts.outgroup
except NameError:
	sys.stderr.write("Outgroup must be defined (--outgroup)")
	sys.exit(1)


t = Tree(opts.tree)
t.set_outgroup(opts.outgroup)
print(t.get_tree_root().write())
