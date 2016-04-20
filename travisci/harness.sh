#!/bin/bash

export PERL5LIB=$PWD/bioperl-live:$PWD/ensembl-test/modules:$PWD/ensembl/modules:$PWD/modules:$PWD/ensembl-hive/modules:$PWD/Bio-HTS/lib:$PWD/Bio-HTS/blib/arch/auto/Bio/DB/HTS/Faidx:$PWD/Bio-HTS/blib/arch/auto/Bio/DB/HTS

export ENSEMBL_CVS_ROOT_DIR=$PWD
export TEST_AUTHOR=$USER
echo "KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK"
perl -c $PWD/ensembl-compara/modules/Bio/EnsEMBL/Compara/RunnableDB/OrthologQM/OrthologFactory.pm
echo "KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK"
echo "Running ensembl-compara test suite using $PERL5LIB"
if [ "$COVERALLS" = 'true' ]; then
  PERL5OPT='-MDevel::Cover=+ignore,bioperl,+ignore,ensembl,+ignore,ensembl-test' perl $PWD/ensembl-test/scripts/runtests.pl -verbose $PWD/modules/t
else
  perl $PWD/ensembl-test/scripts/runtests.pl $PWD/modules/t
fi

rt1=$?

echo "We are running Perl '$TRAVIS_PERL_VERSION'"
if [[ "$TRAVIS_PERL_VERSION" < "5.14" ]]; then
  echo "Skipping ensembl-rest test suite"
else
  export PERL5LIB=$PERL5LIB:$PWD/ensembl-variation/modules:$PWD/ensembl-funcgen/modules:$PWD/ensembl-io/modules:$PWD/ensembl-rest/lib
  echo "Running ensembl-rest test suite using $PERL5LIB"
  REST_SCRIPTS=("$PWD/ensembl-rest/t/genomic_alignment.t" "$PWD/ensembl-rest/t/info.t" "$PWD/ensembl-rest/t/taxonomy.t")
  if [ "$COVERALLS" = 'true' ]; then
    PERL5OPT='-MDevel::Cover=+ignore,bioperl,+ignore,ensembl,+ignore,ensembl-test,+ignore,ensembl-variation,+ignore,ensembl-io,+ignore,ensembl-funcgen' perl $PWD/ensembl-test/scripts/runtests.pl -verbose "${REST_SCRIPTS[@]}"
  else
    perl $PWD/ensembl-test/scripts/runtests.pl "${REST_SCRIPTS[@]}"
  fi
fi

rt=$?
if [[ ($rt1 -eq 0) && ($rt -eq 0) ]]; then
  if [ "$COVERALLS" = 'true' ]; then
    echo "Running Devel::Cover coveralls report"
    cover --nosummary -report coveralls
  fi
  exit $?
else
  exit 255
fi
