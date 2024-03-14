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

use HTTP::Tiny;
use JSON qw(decode_json);
use Test::More;

use Bio::EnsEMBL::ApiVersion qw(software_version);
use Bio::EnsEMBL::Compara::Utils::Test;


my $compara_branch = Bio::EnsEMBL::Compara::Utils::Test::get_repository_branch();
fail('Can get active branch of Compara repo') unless defined $compara_branch;

my $software_version = software_version();
fail('Can get local Ensembl software version') unless defined $software_version;

my $live_version;
my $response = HTTP::Tiny->new->get('https://api.github.com/repos/Ensembl/ensembl-compara');
if ($response->{'success'}) {
    my $content = decode_json($response->{'content'});
    if (exists $content->{'default_branch'}
            && $content->{'default_branch'} =~ m|^release/(?<live_version>[0-9]+)$|) {
        $live_version = $+{'live_version'};
    }
}
fail('Can get live Ensembl release version') unless defined $live_version;


if (defined $compara_branch && !($compara_branch =~ m|^release/[0-9]+$|)) {
    plan skip_all => 'test core schema update check is only run on Ensembl release branches';
}

if (defined $software_version && defined $live_version && $software_version <= $live_version) {
    plan skip_all => 'test core schema update check is not run on an Ensembl version after it has been released';
}


## Check that the test core database schemas are up to date

my $compara_dir = Bio::EnsEMBL::Compara::Utils::Test::get_repository_root();
my $multitestdb = Bio::EnsEMBL::Compara::Utils::Test::create_multitestdb();

# Load the Core schema for reference
my $core_db_name = $multitestdb->create_db_name('core_schema');
my $core_statements = Bio::EnsEMBL::Compara::Utils::Test::read_sqls("$ENV{ENSEMBL_ROOT_DIR}/ensembl/sql/table.sql");
my $core_db = Bio::EnsEMBL::Compara::Utils::Test::load_statements($multitestdb, $core_db_name, $core_statements, 'Can load the reference Core schema');
my $core_schema = Bio::EnsEMBL::Compara::Utils::Test::get_schema_from_database($core_db, $core_db_name);
Bio::EnsEMBL::Compara::Utils::Test::drop_database($multitestdb, $core_db_name);

my $test_db_name = $multitestdb->create_db_name('test_schema');

my $db_dir = "${compara_dir}/src/test_data/databases/core";
foreach my $test_file_name (glob "${db_dir}/*/table.sql") {
    my $short_name = $test_file_name;
    $short_name =~ s{${db_dir}/}{};
    subtest $short_name, sub {
        my $test_statements = Bio::EnsEMBL::Compara::Utils::Test::read_sqls($test_file_name);
        my $test_db = Bio::EnsEMBL::Compara::Utils::Test::load_statements($multitestdb, $test_db_name, $test_statements, 'Can load the test schema');
        my $test_schema = Bio::EnsEMBL::Compara::Utils::Test::get_schema_from_database($test_db, $test_db_name);
        is_deeply($test_schema, $core_schema, 'Test schema identical to the Core schema');
    };
}

Bio::EnsEMBL::Compara::Utils::Test::drop_database($multitestdb, $test_db_name);

done_testing();
