#!/bin/bash

ENSDIR="${ENSDIR:-$PWD}"

export PERL5LIB=$ENSDIR/bioperl-live:$ENSDIR/ensembl/modules:$ENSDIR/ensembl-variation/modules:$ENSDIR/ensembl-test/modules:$ENSDIR/ensembl-io/modules:$ENSDIR/ensembl-orm/modules:$PWD/modules:$PWD/conf
export TEST_AUTHOR=$USER

echo "Running test suite"
perl $ENSDIR/ensembl-test/scripts/runtests.pl modules/t $SKIP_TESTS

rt=$?
if [ $rt -eq 0 ]; then
  exit $?
else
  exit $rt
fi
