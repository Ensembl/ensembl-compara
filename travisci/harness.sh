#!/bin/bash

echo "We are running Perl '$TRAVIS_PERL_VERSION', Coveralls status is set to '$COVERALLS'"

# Setup the environment variables
export ENSEMBL_CVS_ROOT_DIR=$PWD
export TEST_AUTHOR=$USER
export PERL5LIB=$PWD/bioperl-live
export PERL5LIB=$PERL5LIB:$PWD/modules
export PERL5LIB=$PERL5LIB:$PWD/ensembl/modules
export PERL5LIB=$PERL5LIB:$PWD/ensembl-rest/lib
export PERL5LIB=$PERL5LIB:$PWD/ensembl-io/modules
export PERL5LIB=$PERL5LIB:$PWD/ensembl-hive/modules
export PERL5LIB=$PERL5LIB:$PWD/ensembl-test/modules
export PERL5LIB=$PERL5LIB:$PWD/ensembl-funcgen/modules
export PERL5LIB=$PERL5LIB:$PWD/ensembl-variation/modules
export PERL5LIB=$PERL5LIB:$PWD/Bio-HTS/lib:$PWD/Bio-HTS/blib/arch/auto/Bio/DB/HTS/Faidx:$PWD/Bio-HTS/blib/arch/auto/Bio/DB/HTS

ENSEMBL_PERL5OPT='-MDevel::Cover=+ignore,bioperl,+ignore,ensembl,+ignore,ensembl-test,+ignore,ensembl-variation,+ignore,ensembl-io,+ignore,ensembl-funcgen'
ENSEMBL_TESTER="$PWD/ensembl-test/scripts/runtests.pl"
COMPARA_SCRIPTS=("$PWD/modules/t")
CORE_SCRIPTS=("$PWD/ensembl/modules/t/compara.t")
REST_SCRIPTS=("$PWD/ensembl-rest/t/genomic_alignment.t" "$PWD/ensembl-rest/t/info.t" "$PWD/ensembl-rest/t/taxonomy.t" "$PWD/ensembl-rest/t/homology.t")

echo "Running ensembl-compara test suite using $PERL5LIB"
if [ "$COVERALLS" = 'true' ]; then
  PERL5OPT="$ENSEMBL_PERL5OPT" perl $ENSEMBL_TESTER -verbose "${COMPARA_SCRIPTS[@]}"
  PERL5OPT="$ENSEMBL_PERL5OPT" perl $ENSEMBL_TESTER -verbose "${CORE_SCRIPTS[@]}"
else
  perl $ENSEMBL_TESTER "${COMPARA_SCRIPTS[@]}"
  perl $ENSEMBL_TESTER "${CORE_SCRIPTS[@]}"
fi

rt1=$?

if [[ "$TRAVIS_PERL_VERSION" < "5.14" ]]; then
  echo "Skipping ensembl-rest test suite"
else
  echo "Running ensembl-rest test suite using $PERL5LIB"
  if [ "$COVERALLS" = 'true' ]; then
    PERL5OPT="$ENSEMBL_PERL5OPT" perl $ENSEMBL_TESTER -verbose "${REST_SCRIPTS[@]}"
  else
    perl $ENSEMBL_TESTER "${REST_SCRIPTS[@]}"
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
