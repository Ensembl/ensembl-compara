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

use Bio::EnsEMBL::Compara::Utils::Test;


## Check that the schemas test databases are fully compliant with the SQL standard

my $compara_dir = Bio::EnsEMBL::Compara::Utils::Test::get_repository_root();
my $multitestdb = Bio::EnsEMBL::Compara::Utils::Test::create_multitestdb();

# Load the Compara schema for reference
my $compara_db_name = $multitestdb->create_db_name('compara_schema');
my $compara_statements = Bio::EnsEMBL::Compara::Utils::Test::read_sqls("${compara_dir}/sql/table.sql");
my $compara_db = Bio::EnsEMBL::Compara::Utils::Test::load_statements($multitestdb, $compara_db_name, $compara_statements, 'Can load the reference Compara schema');
my $compara_schema = Bio::EnsEMBL::Compara::Utils::Test::get_schema_from_database($compara_db);
Bio::EnsEMBL::Compara::Utils::Test::drop_database($multitestdb, $compara_db_name);

# Load the Core schema for reference
my $core_db_name = $multitestdb->create_db_name('core_schema');
my $core_statements = Bio::EnsEMBL::Compara::Utils::Test::read_sqls("$ENV{ENSEMBL_CVS_ROOT_DIR}/ensembl/sql/table.sql");
my $core_db = Bio::EnsEMBL::Compara::Utils::Test::load_statements($multitestdb, $core_db_name, $core_statements, 'Can load the reference Core schema');
my $core_schema = Bio::EnsEMBL::Compara::Utils::Test::get_schema_from_database($core_db);
Bio::EnsEMBL::Compara::Utils::Test::drop_database($multitestdb, $core_db_name);

my $test_db_name = $multitestdb->create_db_name('test_schema');
my $db_dir = "${compara_dir}/modules/t/test-genome-DBs";
foreach my $test_file_name (glob "${db_dir}/*/*/table.sql") {
    my $short_name = $test_file_name;
    $short_name =~ s{${db_dir}/}{};
    subtest $short_name, sub {
        my $test_statements = Bio::EnsEMBL::Compara::Utils::Test::read_sqls($test_file_name);
        my $test_db = Bio::EnsEMBL::Compara::Utils::Test::load_statements($multitestdb, $test_db_name, $test_statements, 'Can load the test schema');
        my $test_schema = Bio::EnsEMBL::Compara::Utils::Test::get_schema_from_database($test_db);
        if ($short_name =~ /\/core\/table.sql$/) {
            is_deeply($test_schema, $core_schema, 'Test schema identical to the Core schema');
        } else {
            is_deeply($test_schema, $compara_schema, 'Test schema identical to the Compara schema');
        }
    };
}

Bio::EnsEMBL::Compara::Utils::Test::drop_database($multitestdb, $test_db_name);

done_testing();
