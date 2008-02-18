#! /usr/bin/tcsh

setenv CVS_RSH ssh

source /software/ensembl_web/perlset

/ensemblweb/head/utils/integration/deploy.pl /ensemblweb/head/utils/integration/deploy.yml

