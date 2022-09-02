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
use Test::Exception;

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "homology" );
my $compara_dba = $multi->get_DBAdaptor( "compara" );

my $gene_tree_adaptor = $compara_dba->get_GeneTreeAdaptor();
my $gdb = $compara_dba->get_GenomeDBAdaptor->fetch_by_name_assembly("tarsius_syrichta");
my $gene_member = $compara_dba->get_GeneMemberAdaptor->fetch_by_stable_id_GenomeDB("ENSTSYG00000021671", $gdb);
my $gene_tree_other = $gene_tree_adaptor->fetch_default_for_Member($gene_member, "other");
my $gene_tree_default = $gene_tree_adaptor->fetch_default_for_Member($gene_member, "default");

subtest "Test Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor delete_tree method", sub {

    my $default_before = $gene_member->has_GeneTree("default");
    my $other_before = $gene_member->has_GeneTree("other");
    is($default_before, 1, "Num default trees");
    is($other_before, 1, "Num other trees");
    $gene_tree_adaptor->delete_tree($gene_tree_default);
    $gene_member = $compara_dba->get_GeneMemberAdaptor->fetch_by_stable_id_GenomeDB("ENSTSYG00000021671", $gdb);
    my $default_after = $gene_member->has_GeneTree("default");
    my $other_after = $gene_member->has_GeneTree("other");
    is($default_after, 0, "Num default tree after delete");
    is($other_after, $other_before, "Num other tree after default delete");

    done_testing();
};

done_testing();
