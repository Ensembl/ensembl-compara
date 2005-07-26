#!/usr/bin/env jython

import ensembl
import time, sys


def measure_iteration(iter, label):
    """Runs the function 'fn' and counts the number of items returned and prints
    the number of seconds it takes to perform the iteration."""
    t = time.time()
    n = 0
    for g in iter:
        n = n+1
    print n, time.time()-t,"secs", label
    sys.stdout.flush()

print ensembl.s_cerevisiae.geneAdaptor.fetchCount(), "fetchCount()"
sys.stdout.flush()
measure_iteration(ensembl.s_cerevisiae.all_genes(0), "all_genes")
measure_iteration(ensembl.s_cerevisiae.geneAdaptor.fetchIterator(0), "fetchIterator")

