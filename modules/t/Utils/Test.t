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

use File::Spec;
use Test::More tests => 3;

use_ok('Bio::EnsEMBL::Compara::Utils::Test');

subtest 'get_repository_root' => sub {
    my $path = Bio::EnsEMBL::Compara::Utils::Test::get_repository_root();
    ok(-d $path, "Returned a directory");
    foreach my $subdir (qw(modules scripts sql modules/Bio/EnsEMBL/Compara)) {
        my $subpath = File::Spec->catdir($path, $subdir);
        ok(-d $subpath, "$path has a sub-directory named '$subdir'");
    }
};

subtest 'get_pipeline_tables_create_statements' => sub {
    my $one_table = Bio::EnsEMBL::Compara::Utils::Test::get_pipeline_tables_create_statements(['dnafrag_chunk']);
    is(scalar(@$one_table), 1, 'Only one table');
    is(ref($one_table->[0]), 'ARRAY', 'The table is represented as an array-ref');
    is($one_table->[0]->[0], 'CREATE TABLE dnafrag_chunk', 'Title properly formatted');
    like($one_table->[0]->[1], qr/^CREATE TABLE dnafrag_chunk/, 'The SQL is a CREATE statement');
    like($one_table->[0]->[1], qr/dnafrag_chunk_id.*PRIMARY\s+KEY/s, 'The CREATE statement has the definition of the primary key');

    my $all_tables = Bio::EnsEMBL::Compara::Utils::Test::get_pipeline_tables_create_statements();
    cmp_ok(scalar(@$all_tables), '>', 1, 'More than one table');
    my @filtered_tables = grep {$_->[0] eq 'CREATE TABLE dnafrag_chunk'} @$all_tables;
    is(scalar(@filtered_tables), 1, 'The dnafrag_chunk table is there');
};

done_testing();
