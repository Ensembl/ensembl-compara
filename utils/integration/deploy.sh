#! /usr/bin/tcsh

setenv CVS_RSH ssh
source /localsw/ensembl_web/perlset

/ensemblweb/head/utils/integration/deploy.pl /ensemblweb/head/utils/integration/deploy.yml
