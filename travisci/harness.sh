#!/bin/bash

export PERL5LIB=$PWD/bioperl-live-bioperl-release-1-2-3:$PWD/ensembl-test/modules:$PWD/ensembl/modules:$PWD/modules
export ENSEMBL_CVS_ROOT_DIR=$PWD

echo "Running ensembl-compara test suite using $PERL5LIB"
if [ "$COVERALLS" = 'true' ]; then
  PERL5OPT='-MDevel::Cover=+ignore,bioperl,+ignore,ensembl,+ignore,ensembl-test' perl $PWD/ensembl-test/scripts/runtests.pl -verbose $PWD/modules/t
else
  perl $PWD/ensembl-test/scripts/runtests.pl $PWD/modules/t
fi

if [ $? -ne 0 ]; then
  exit $?
fi

echo "We are running Perl '$TRAVIS_PERL_VERSION'"
if [[ "$TRAVIS_PERL_VERSION" < "5.14" ]]; then
  echo "Skipping ensembl-rest test suite on Perl $TRAVIS_PERL_VERSION"
else
  export PERL5LIB=$PERL5LIB:$PWD/ensembl-variation/modules:$PWD/ensembl-funcgen/modules:$PWD/ensembl-io/modules:$PWD/ensembl-rest/lib
  echo "Running ensembl-rest test suite using $PERL5LIB"
  REST_SCRIPTS=("$PWD/ensembl-rest/t/genomic_alignment.t" "$PWD/ensembl-rest/t/info.t" "$PWD/ensembl-rest/t/taxonomy.t")
  if [ "$COVERALLS" = 'true' ]; then
    #PERL5OPT='-MDevel::Cover=+ignore,bioperl,+ignore,ensembl,+ignore,ensembl-test,+ignore,ensembl-variation,+ignore,ensembl-io,+ignore,ensembl-funcgen' perl $PWD/ensembl-test/scripts/runtests.pl -verbose "${REST_SCRIPTS[@]}"
    perl $PWD/ensembl-test/scripts/runtests.pl "${REST_SCRIPTS[@]}"
  else
    perl $PWD/ensembl-test/scripts/runtests.pl "${REST_SCRIPTS[@]}"
  fi
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
