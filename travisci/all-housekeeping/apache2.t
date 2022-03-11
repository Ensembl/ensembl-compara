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

use strict;
use warnings;

use Test::More;

use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Compara::Utils::Test;
use Bio::EnsEMBL::Utils::IO qw/:slurp/;

use Time::Piece;

my @all_files = Bio::EnsEMBL::Compara::Utils::Test::find_all_files();

foreach my $f (@all_files) {
    next unless $f =~ /\.([chtr]|p[lmy]|sh|java|(my|pg|)sql|sqlite)$/i;
    # Except the .sql of the test-database dumps
    next if $f =~ /modules\/t\/test-genome-DBs\/.*\.sql$/;
    next if $f =~ /src\/test_data\/.*\.sql$/;
    # Fake libraries
    next if $f =~ /\/fake_libs\//;
    # CLEAN.t
    next if $f =~ /\/CLEAN.t$/;
    # And Apollo's code
    next if $f =~ /scripts\/synteny\/(apollo|BuildSynteny|SyntenyManifest.txt)/;
    has_apache2_licence($f, 'no_affiliation');
}

my $repo_root = Bio::EnsEMBL::Compara::Utils::Test::get_repository_root();

# check LICENSE file
my $licence = "$repo_root/LICENSE";
ok( -e $licence, 'LICENCE file exists');
open(my $licence_fh, '<', $licence) or die "Cannot open file $licence for reading";
my $found_licence_name = 0;
my $found_licence_version = 0;
while ( not ($found_licence_name && $found_licence_version) ) {
    my $line = <$licence_fh>;
    $found_licence_name = 1 if $line =~ /Apache License/;
    $found_licence_version = 1 if $line =~ /Version 2\.0/;
}
close $licence_fh;
ok( $found_licence_name && $found_licence_version, 'LICENSE name and version correct' );


# check NOTICE file
my $notice = "$repo_root/NOTICE";
my $current_year = Time::Piece->new()->year();
my $expected_notice = <<"END_NOTICE";
Ensembl
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-$current_year] EMBL-European Bioinformatics Institute

This product includes software developed at:
- EMBL-European Bioinformatics Institute
- Wellcome Trust Sanger Institute
END_NOTICE
my $notice_contents = slurp($notice);
is( $notice_contents, $expected_notice, 'NOTICE file contents correct' );

done_testing();
