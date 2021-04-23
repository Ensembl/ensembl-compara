#!/usr/bin/env perl
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

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);

use File::Temp qw/tempfile/;

# Check module can be seen and compiled
use_ok('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpWGAExpectedTags');

# Load test DB
my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new( "test_master" );
my $compara_dba = $multi_db->get_DBAdaptor( "compara" );
my $dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $compara_dba->dbc);
my $compara_db = $dbc->url;

# Number of tags before calling the module
my $num_tags_query = "SELECT COUNT(*) FROM method_link_species_set_tag";
my ($num_tags_before) = $dbc->db_handle->selectrow_array($num_tags_query);

my $num_wga_exp_query = "SELECT COUNT(*) FROM method_link_species_set_tag WHERE tag = 'wga_expected'";
my ($num_wga_exp_before) = $dbc->db_handle->selectrow_array($num_wga_exp_query);

my ($wga_exp_fh, $test_wga_expected_file) = tempfile();
standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpWGAExpectedTags', # module
    { # input param hash
        'wga_expected_file' => $test_wga_expected_file,
        'compara_db'        => $compara_db,
    }
);

# Check that output file exists and is correct
my $exp_output = [
    "method_link_species_set_id\twga_expected\n",
    "101\t1\n",
    "102\t0\n",
    "104\t0\n",
    "105\t1\n",
    "106\t1\n",
];

open( my $fh, '<', $test_wga_expected_file) or die "Cannot open $test_wga_expected_file for reading\n";
my @got_output = <$fh>;

is_deeply( \@got_output, $exp_output, 'wga_expected tags dumped correctly to a file' );

# Check that only wga_expected tags are deleted from the database
my ($num_wga_exp_after) = $dbc->db_handle->selectrow_array($num_wga_exp_query);

my ($num_tags_after) = $dbc->db_handle->selectrow_array($num_tags_query);

is( $num_wga_exp_after, 0, 'All wga_expected tags deleted from the method_link_species_set_tag table' );
is( $num_tags_after, $num_tags_before - $num_wga_exp_before, 'The number of remaining entries in method_link_species_set_tag is correct' );

done_testing();
