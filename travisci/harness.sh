#!/bin/bash

ENSDIR="${ENSDIR:-$PWD}"

## Install mod_perl manually
cd $ENSDIR
curl http://mirrors.muzzy.org.uk/apache//httpd/httpd-2.2.31.tar.gz > apache.tar.gz
curl http://apache.org/dist/perl/mod_perl-2.0.9.tar.gz > mod_perl.tar.gz
tar zxf apache.tar.gz
tar zxf mod_perl.tar.gz | tar xvf -
cd httpd-2.2.31
./configure --enable-deflate --prefix=$ENSDIR/apache2
cd ../mod_perl-2.0.9

perl Makefile.PL PREFIX=$ENSDIR/apache2 MP_APXS=$ENSDIR/apache2/bin/apxs
make
make install

## Proceed with test harness

export PERL5LIB=$ENSDIR/bioperl-live:$ENSDIR/ensembl/modules:$ENSDIR/ensembl-variation/modules:$ENSDIR/ensembl-test/modules:$ENSDIR/ensembl-io/modules::$ENSDIR/ensembl-webcode/modules:$PWD/modules
export TEST_AUTHOR=$USER

echo "Running test suite"
perl $ENSDIR/ensembl-test/scripts/runtests.pl modules/t $SKIP_TESTS

rt=$?
if [ $rt -eq 0 ]; then
  exit $?
else
  exit $rt
fi
