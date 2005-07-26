#!/usr/bin/env jython

from __future__ import nested_scopes

__version__ = "$Revision$"

import sys

import ensembl

FILENAME = "ensembl-sources.tab"

SQL_DUMP_SOURCES = """SELECT name,
assembly,
genebuild
FROM genome_db"""

## locator column only used during genebuild
## removed for release
##
## MID(locator,
##     LOCATE("dbname=", locator)+LENGTH("dbname="),
##     LENGTH(locator)-LOCATE(";", REVERSE(locator))+1-LOCATE("dbname=", locator)-LENGTH("dbname=")) as dbname
## 

def dump_sources(filename=FILENAME):
    ensembl.compara.sql(SQL_DUMP_SOURCES, outfile=open(filename, "w"))

def main(args):
    dump_sources()

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
