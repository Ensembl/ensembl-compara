#!/usr/bin/env jython

__version__ = "$Revision$"

"""
ensdescribe.py -- describe Ensembl IDs in a tab-delimited text file

ensdescribe.py COL... < inputfile

Each COL is a column in the tab-delimited input file that contains an
Ensembl accession ID.

Example:

$ echo ENSG00000139618 | ensdescribe.py 1
ENSG00000139618 BRCA2   BREAST CANCER TYPE 2 SUSCEPTIBILITY PROTEIN. [Source:SWISSPROT;Acc:P51587]
"""

import re
import sys
from xreadlines import xreadlines

import org

import ensembl

def enumerate_list(seq):
    """
    enumerate_list(["a", "b", "c"]) -> [(0, "a"), (1, "b"), (2, "c")]
    """
    return zip(xrange(len(seq)), seq)

def main(args):
    marked_column_indexes = [int(arg)-1 for arg in args]
    
    for line in xreadlines(sys.stdin):  # this is the same as python 2.2 "for line in sys.stdin:"
        cols = line.rstrip().split("\t")
        for col_index, col in enumerate_list(cols):
            if col_index in marked_column_indexes:
                feature = ensembl.fetch(col)
                
                if isinstance(feature, ensembl.datamodel.Translation):
                    name = feature.transcript.displayName
                    description = feature.transcript.gene.description
                    
                elif isinstance(feature, ensembl.datamodel.Transcript):
                    name = feature.displayName
                    description = feature.gene.description
                    
                else:
                    name = feature.displayName
                    description = feature.description

                cols[col_index] = "\t".join([col, name, description])

        print "\t".join(cols)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:])) # system return status = main(arguments without the name of the script)

