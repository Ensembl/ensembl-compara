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


use Test::Exception;
use Test::More;

use Bio::EnsEMBL::Utils::IO qw (slurp);
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::Utils::Test;

sub is_valid_newick {
    my $filename = shift;

    my $content = slurp($filename);
    lives_ok(
        sub { Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($content) },
        "$filename is a valid Newick/NHX file"
    );
}

my @all_files = Bio::EnsEMBL::Compara::Utils::Test::find_all_files();

foreach my $f (@all_files) {
    if ($f =~ /\.(nh|nhx|nw|nwk)$/) {
        is_valid_newick($f);
    }
}

done_testing();

