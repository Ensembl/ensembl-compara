#!/bin/bash

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


echo "We are running Perl '$TRAVIS_PERL_VERSION', Coveralls status is set to '$COVERALLS'"

# Setup the environment variables
export ENSEMBL_CVS_ROOT_DIR=$PWD
export EHIVE_ROOT_DIR=$PWD/ensembl-hive
export TEST_AUTHOR=$USER
export PERL5LIB=$PWD/bioperl-live
export PERL5LIB=$PERL5LIB:$PWD/bioperl-run/lib
export PERL5LIB=$PERL5LIB:$PWD/modules
export PERL5LIB=$PERL5LIB:$PWD/travisci/fake_libs/
export PERL5LIB=$PERL5LIB:$PWD/ensembl/modules
export PERL5LIB=$PERL5LIB:$PWD/ensembl-rest/lib
export PERL5LIB=$PERL5LIB:$PWD/ensembl-hive/modules
export PERL5LIB=$PERL5LIB:$PWD/ensembl-test/modules
export PERL5LIB=$PERL5LIB:$PWD/ensembl-funcgen/modules
export PERL5LIB=$PERL5LIB:$PWD/ensembl-variation/modules
export PERL5LIB=$PERL5LIB:$PWD/ensembl-analysis/modules

ENSEMBL_PERL5OPT='-MDevel::Cover=+ignore,bioperl,+ignore,ensembl,+ignore,ensembl-test,+ignore,ensembl-variation,+ignore,ensembl-funcgen'
ENSEMBL_TESTER="$PWD/ensembl-test/scripts/runtests.pl"
COMPARA_SCRIPTS=("$PWD/modules/t")
CORE_SCRIPTS=("$PWD/ensembl/modules/t/compara.t")
REST_SCRIPTS=("$PWD/ensembl-rest/t/genomic_alignment.t" "$PWD/ensembl-rest/t/info.t" "$PWD/ensembl-rest/t/taxonomy.t" "$PWD/ensembl-rest/t/homology.t" "$PWD/ensembl-rest/t/gene_tree.t" "$PWD/ensembl-rest/t/cafe_tree.t" "$PWD/ensembl-rest/t/family.t")

if [ "$COVERALLS" = 'true' ]; then
  EFFECTIVE_PERL5OPT="$ENSEMBL_PERL5OPT"
  ENSEMBL_TESTER="$ENSEMBL_TESTER -verbose"
else
  EFFECTIVE_PERL5OPT=""
fi

echo "Running ensembl-compara test suite using $PERL5LIB"
PERL5OPT="$EFFECTIVE_PERL5OPT" perl $ENSEMBL_TESTER "${COMPARA_SCRIPTS[@]}"
rt1=$?
PERL5OPT="$EFFECTIVE_PERL5OPT" perl $ENSEMBL_TESTER "${CORE_SCRIPTS[@]}"
rt2=$?

if [[ "$TRAVIS_PERL_VERSION" != "5.14" ]]; then
  echo "Skipping ensembl-rest test suite"
  rt3=0
else
  echo "Running ensembl-rest test suite using $PERL5LIB"
  PERL5OPT="$EFFECTIVE_PERL5OPT" perl $ENSEMBL_TESTER "${REST_SCRIPTS[@]}"
  rt3=$?
fi

# Check that all the Perl files can be compiled
find docs modules scripts sql travisci -iname '*.t' -o -iname '*.pl' -o -iname '*.pm' \! -name 'LoadSynonyms.pm' \! -name 'HALAdaptor.pm' \! -name 'HALXS.pm' -print0 | xargs -0 -n 1 perl -c
rt4=$?

if [[ ($rt1 -eq 0) && ($rt2 -eq 0) && ($rt3 -eq 0) && ($rt4 -eq 0) ]]; then
  if [ "$COVERALLS" = 'true' ]; then
    echo "Running Devel::Cover coveralls report"
    cover --nosummary -report coveralls
  fi
  exit $?
else
  exit 255
fi
