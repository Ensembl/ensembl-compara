#!/bin/bash

ENSDIR="${ENSDIR:-$PWD}"

export PERL5LIB=$ENSDIR/ensembl-test/modules:$ENSDIR/ensembl-io/modules::$ENSDIR/ensembl-webcode/modules:$PWD/modules
export TEST_AUTHOR=$USER

echo "Running test suite"
perl $ENSDIR/ensembl-test/scripts/runtests.pl modules/t $SKIP_TESTS

rt=$?
if [ $rt -eq 0 ]; then
  exit $?
else
  exit $rt
fi
