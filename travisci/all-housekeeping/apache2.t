# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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

use strict;
use warnings;

use Test::More;

use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Compara::Utils::Test;

my @all_files = Bio::EnsEMBL::Compara::Utils::Test::find_all_files();

foreach my $f (@all_files) {
    next unless $f =~ /\.([chtr]|p[lmy]|sh|java|(my|pg|)sql|sqlite)$/i;
    # Except the .sql of the test-database dumps
    next if $f =~ /modules\/t\/test-genome-DBs\/.*\.sql$/;
    next if $f =~ /src\/python\/tests\/databases\/.*\.sql$/;
    # Fake libraries
    next if $f =~ /\/fake_libs\//;
    # CLEAN.t
    next if $f =~ /\/CLEAN.t$/;
    # And Apollo's code
    next if $f =~ /scripts\/synteny\/(apollo|BuildSynteny|SyntenyManifest.txt)/;
    has_apache2_licence($f);
}

done_testing();
