#!/homes/carlac/anaconda_ete/bin/python
import sys, os
from ete3 import Tree

infile = sys.argv[1]
if not os.path.isfile(infile):
	sys.stderr.write("File %s not found", infile)
	sys.exit(1)

t = Tree(infile)
root = t.get_tree_root()
root.unroot()
print(root.write())
