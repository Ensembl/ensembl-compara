#!/bin/bash

# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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


echo "We are running Perl '$TRAVIS_PERL_VERSION', Coverage reporting is set to '$COVERAGE'"

# Setup the environment variables
ENSEMBL_PERL5OPT='-MDevel::Cover=+ignore,bioperl,+ignore,ensembl,+ignore,ensembl-test,+ignore,ensembl-variation,+ignore,ensembl-funcgen'
ENSEMBL_TESTER="$PWD/ensembl-test/scripts/runtests.pl"
ENSEMBL_TESTER_OPTIONS=()
CORE_SCRIPTS=("$PWD/ensembl/modules/t/compara.t")
REST_SCRIPTS=("$PWD/ensembl-rest/t/genomic_alignment.t" "$PWD/ensembl-rest/t/info.t" "$PWD/ensembl-rest/t/taxonomy.t" "$PWD/ensembl-rest/t/homology.t" "$PWD/ensembl-rest/t/gene_tree.t" "$PWD/ensembl-rest/t/cafe_tree.t")

if [ "$COVERAGE" = 'true' ]; then
  EFFECTIVE_PERL5OPT="$ENSEMBL_PERL5OPT"
  ENSEMBL_TESTER_OPTIONS+=('-verbose')
else
  EFFECTIVE_PERL5OPT=""
fi

echo "Running ensembl test suite using $PERL5LIB"
PERL5OPT="$EFFECTIVE_PERL5OPT" perl "$ENSEMBL_TESTER" "${ENSEMBL_TESTER_OPTIONS[@]}" "${CORE_SCRIPTS[@]}"
rt1=$?

echo "Running ensembl-rest test suite using $PERL5LIB"
PERL5OPT="$EFFECTIVE_PERL5OPT" perl "$ENSEMBL_TESTER" "${ENSEMBL_TESTER_OPTIONS[@]}" "${REST_SCRIPTS[@]}"
rt2=$?

if [[ ($rt1 -eq 0) && ($rt2 -eq 0) ]]; then
  exit 0
else
  exit 255
fi
