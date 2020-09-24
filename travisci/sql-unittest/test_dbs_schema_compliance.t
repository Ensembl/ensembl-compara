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
my $db_name = $multitestdb->create_db_name('schema');

my $db_dir = "${compara_dir}/modules/t/test-genome-DBs";
foreach my $test_file_name (glob "${db_dir}/*/*/table.sql") {
  my $short_name = $test_file_name;
  $short_name =~ s{${db_dir}/}{};
  my $statements = Bio::EnsEMBL::Compara::Utils::Test::read_sqls($test_file_name);
  foreach my $server_mode (qw(TRADITIONAL ANSI)) {
    subtest "$short_name in $server_mode mode", sub {
        Bio::EnsEMBL::Compara::Utils::Test::test_schema_compliance($multitestdb, $db_name, $statements, $server_mode);
    };
  }
}

Bio::EnsEMBL::Compara::Utils::Test::drop_database($multitestdb, $db_name);

done_testing();
