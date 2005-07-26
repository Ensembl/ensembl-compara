#!/usr/bin/env jython

__version__ = "$Revision$"

"""
enspeptidize.py -- get peptide accession IDs of longest translatoin

ensdescribe.py COL... < inputfile

Each COL is a column in the tab-delimited input file that contains an
Ensembl accession ID.

Example:

$ echo ENSG00000139618 | enspeptidize.py 1 2> /dev/null
ENSG00000139618 ENSP00000267071
"""

import re
import sys
from xreadlines import xreadlines

import ensembl

def enumerate_list(seq):
    """
    enumerate_list(["a", "b", "c"]) -> [(0, "a"), (1, "b"), (2, "c")]
    """
    return zip(xrange(len(seq)), seq)

def main(args):
    marked_column_indexes = [int(arg)-1 for arg in args]

    for line in xreadlines(sys.stdin): # this is the same as python 2.2 "for line in sys.stdin:"
        cols = line.rstrip().split("\t")
        for col_index, col in enumerate_list(cols):
            if col_index in marked_column_indexes:
                print >>sys.stderr, col
                
                gene = ensembl.fetch(col)
                longest_transcript = max([(transcript.length, transcript) for transcript in gene.transcripts])[1]
                peptide_ensid = longest_transcript.translation.accessionID
                cols[col_index] = "\t".join([col, peptide_ensid])

        print "\t".join(cols)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:])) # system return status = main(arguments without the name of the script)
