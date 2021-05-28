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

set -euxo pipefail

cd "$ENSEMBL_ROOT_DIR"
prove -r ensembl-compara/travisci/all-housekeeping/
ensembl-test/scripts/runtests.pl ensembl-compara/modules/t
ensembl-test/scripts/runtests.pl ensembl/modules/t/compara.t
ensembl-test/scripts/runtests.pl ensembl-rest/t/genomic_alignment.t ensembl-rest/t/info.t ensembl-rest/t/taxonomy.t ensembl-rest/t/homology.t ensembl-rest/t/gene_tree.t ensembl-rest/t/cafe_tree.t ensembl-rest/t/family.t
cd "$ENSEMBL_ROOT_DIR/ensembl-compara"
./travisci/perl-linter_harness.sh
find docs modules scripts sql travisci -iname '*.t' -print0 | xargs -0 -n 1 perl -c
find docs modules scripts sql travisci -iname '*.pl' -print0 | xargs -0 -n 1 perl -c
find docs modules scripts sql travisci -iname '*.pm' \! -name 'LoadSynonyms.pm' \! -name 'HALAdaptor.pm' \! -name 'HALXS.pm' -print0 | xargs -0 -n 1 perl -c
echo "All good !"
