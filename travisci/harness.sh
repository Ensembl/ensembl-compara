#!/bin/bash

export PERL5LIB=$PWD/bioperl-live-bioperl-release-1-2-3:$PWD/ensembl-test/modules:$PWD/ensembl/modules:$PWD/modules
export ENSEMBL_CVS_ROOT_DIR=$PWD

echo "Running ensembl-compara test suite using $PERL5LIB"
if [ "$COVERALLS" = 'true' ]; then
  PERL5OPT='-MDevel::Cover=+ignore,bioperl,+ignore,ensembl,+ignore,ensembl-test' perl $PWD/ensembl-test/scripts/runtests.pl -verbose $PWD/modules/t
else
  perl $PWD/ensembl-test/scripts/runtests.pl $PWD/modules/t
fi

export PERL5LIB=$PERL5LIB:/nfs/users/nfs_m/mm14/src/perl/perl5:/nfs/users/nfs_m/mm14/src/perl/lib:$PWD/ensembl-variation/modules:$PWD/ensembl-funcgen/modules:$PWD/ensembl-io/modules:$PWD/ensembl-rest/lib

echo "Running ensembl-rest test suite using $PERL5LIB"
if [ "$COVERALLS" = 'true' ]; then
  #PERL5OPT='-MDevel::Cover=+ignore,bioperl,+ignore,ensembl,+ignore,ensembl-test,+ignore,ensembl-variation,+ignore,ensembl-io,+ignore,ensembl-funcgen' perl $PWD/ensembl-test/scripts/runtests.pl -verbose $PWD/ensembl-rest/t/genomic_alignment.t $PWD/ensembl-rest/t/info.t $PWD/ensembl-rest/t/taxonomy.t
  perl $PWD/ensembl-test/scripts/runtests.pl $PWD/ensembl-rest/t/genomic_alignment.t $PWD/ensembl-rest/t/info.t $PWD/ensembl-rest/t/taxonomy.t
else
  perl $PWD/ensembl-test/scripts/runtests.pl $PWD/ensembl-rest/t/genomic_alignment.t $PWD/ensembl-rest/t/info.t $PWD/ensembl-rest/t/taxonomy.t
fi

rt=$?
if [ $rt -eq 0 ]; then
  if [ "$COVERALLS" = 'true' ]; then
    echo "Running Devel::Cover coveralls report"
    cover --nosummary -report coveralls
  fi
  exit $?
else
  exit $rt
fi
