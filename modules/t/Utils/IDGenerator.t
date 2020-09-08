#!/usr/bin/env perl
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
use Test::Exception;

use Bio::EnsEMBL::DBSQL::DBConnection;

use Bio::EnsEMBL::Compara::Utils::IDGenerator qw(:all);
use Bio::EnsEMBL::Compara::Utils::Test;

my $compara_dir = Bio::EnsEMBL::Compara::Utils::Test::get_repository_root();
my $multitestdb = Bio::EnsEMBL::Compara::Utils::Test::create_multitestdb();
my $statements  = Bio::EnsEMBL::Compara::Utils::Test::read_sqls("${compara_dir}/sql/pipeline-tables.sql");

my $db_name = $multitestdb->create_db_name('schema');
$multitestdb->create_and_use_db($multitestdb->dbi_connection(), $db_name);

my @create_sql  = grep {($_->[0] eq 'CREATE TABLE id_generator') || ($_->[0] eq 'CREATE TABLE id_assignments')} @$statements;
Bio::EnsEMBL::Compara::Utils::Test::load_statements($multitestdb, $db_name, \@create_sql, 'Create the ID generation table');

my $dbc = Bio::EnsEMBL::DBSQL::DBConnection->new(
    '-host'        => $multitestdb->db_conf->{'host'},
    '-port'        => $multitestdb->db_conf->{'port'},
    '-user'        => $multitestdb->db_conf->{'user'},
    '-pass'        => $multitestdb->db_conf->{'pass'},
    '-dbname'      => $db_name,
);


sub _test_helper {
    my ($label, $n_ids, $requestor, $expected_dbID) = @_;
    my $got_dbID = get_id_range($dbc, $label, $n_ids, $requestor);
    is($got_dbID, $expected_dbID, "Got $expected_dbID for ${n_ids} ID of label ${label}".($requestor ? " (requestor=$requestor)" : ''));
}

subtest "Without a requestor" => sub {

    throws_ok {get_id_range($dbc, 'A', 0)}  qr/Can only request a positive number of IDs/, 'Throws when requesting 0 IDs';
    throws_ok {get_id_range($dbc, 'A', -1)} qr/Can only request a positive number of IDs/, 'Throws when requesting -1 IDs';

    # - IDs of each type (A and B) keep on increasing
    # - They are managed independently, so can overlap
    _test_helper('A', 1, undef, 1);
    _test_helper('A', 5, undef, 2);
    _test_helper('B', 3, undef, 1);
    _test_helper('A', 3, undef, 7);
    _test_helper('B', 1, undef, 4);
};

subtest "With a requestor" => sub {
    # IDs continue where we left them
    _test_helper('A', 1, 44, 10);
    _test_helper('B', 1, 55,  5);
    # Same call -> same ID
    _test_helper('A', 1, 44, 10);
    # Bigger size for same requestor -> new ID
    _test_helper('A', 5, 44, 11);
    # Same call -> same ID
    _test_helper('A', 5, 44, 11);
    # New requestor -> new IS
    _test_helper('A', 5, 55, 16);
    # Same call -> same ID
    _test_helper('A', 5, 44, 11);
    # Smaller size -> same ID
    _test_helper('A', 2, 55, 16);
    # Same call -> same ID
    _test_helper('A', 5, 55, 16);
};

done_testing();

