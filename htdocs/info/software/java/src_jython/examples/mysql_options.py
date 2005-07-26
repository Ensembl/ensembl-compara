#!/usr/bin/env jython

from __future__ import nested_scopes

__version__ = "$Revision$"

import sys

import ensembl

PARAM_NAMES = ["host", "port", "user", "password", "database"]

def mysql_options(facade_name):
    configuration = getattr(ensembl, facade_name).driver.configuration
    options = ["--%s=%s" % (param_name, configuration[param_name]) for param_name in PARAM_NAMES]
    print " ".join(options)
    
def main(args):
    mysql_options(*args)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
