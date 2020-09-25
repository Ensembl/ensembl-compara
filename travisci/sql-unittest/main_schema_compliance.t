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


## Check that the main schema is fully compliant with the SQL standard

my $compara_dir = Bio::EnsEMBL::Compara::Utils::Test::get_repository_root();
my $multitestdb = Bio::EnsEMBL::Compara::Utils::Test::create_multitestdb();
my $db_name = $multitestdb->create_db_name('schema');

my $statements1 = Bio::EnsEMBL::Compara::Utils::Test::read_sqls("${compara_dir}/sql/table.sql", 'with_fk');
my $statements2 = Bio::EnsEMBL::Compara::Utils::Test::read_sqls("${compara_dir}/sql/pipeline-tables.sql", 'with_fk');
my @statements = (@$statements1, @$statements2);

foreach my $server_mode (qw(TRADITIONAL ANSI)) {
    subtest "$server_mode mode", sub {
        Bio::EnsEMBL::Compara::Utils::Test::test_schema_compliance($multitestdb, $db_name, \@statements, $server_mode);
    };
}

# No need to drop the database because it will be destroyed when
# $multitestdb goes out of scope

done_testing();
