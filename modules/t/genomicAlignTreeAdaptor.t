#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

#use Bio::EnsEMBL::Compara::GenomicAlignTree;

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );

my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new( "homo_sapiens" );

my $genomic_align_tree_adaptor = $compara_db_adaptor->get_GenomicAlignTreeAdaptor();
my $genomic_align_block_adaptor = $compara_db_adaptor->get_GenomicAlignBlockAdaptor();
my $method_link_species_set_adaptor = $compara_db_adaptor->get_MethodLinkSpeciesSetAdaptor();
my $dnafrag_adaptor = $compara_db_adaptor->get_DnaFragAdaptor();

my $epo_species_set_name = "mammals";
my $epo_method_type = "EPO";

my $mlss_epo = $method_link_species_set_adaptor->fetch_by_method_link_type_species_set_name($epo_method_type, $epo_species_set_name);
my $mlss_id_epo = $mlss_epo->dbID;

my $sth = $compara_db_adaptor->dbc->prepare("SELECT node_id, parent_id, root_id, left_index, right_index, left_node_id, right_node_id, distance_to_parent, genomic_align_id, genomic_align_block_id, method_link_species_set_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand, cigar_line FROM genomic_align_tree JOIN genomic_align USING (node_id) WHERE method_link_species_set_id = $mlss_id_epo LIMIT 1");
$sth->execute();
my ($node_id, $parent_id, $root_id, $left_index, $right_index, $left_node_id, $right_node_id, $distance_to_parent, $genomic_align_id, $genomic_align_block_id, $method_link_species_set_id, $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand, $cigar_line) = $sth->fetchrow_array();
$sth->finish();

my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);

#Need to get a tree somehow to test the methods but I don't think I can create one from scratch....

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignTreeAdaptor fetch_all_by_MethodLinkSpeciesSet method", sub {
    my ($num_epo) =  $compara_db_adaptor->dbc->db_handle->selectrow_array("
    SELECT count(distinct root_id)
    FROM genomic_align_tree
    JOIN genomic_align USING (node_id)
    WHERE method_link_species_set_id = $mlss_id_epo");

    my $genomic_align_trees = $genomic_align_tree_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss_epo);

    is(scalar @$genomic_align_trees, $num_epo, "Num genomic_align_trees");

    $genomic_align_trees = $genomic_align_tree_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss_epo, 5);
    is(scalar @$genomic_align_trees, 5, "Num genomic_align_trees with limit");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignTreeAdaptor fetch_all_by_MethodLinkSpeciesSet_DnaFrag method", sub {
    
    my ($num_epo) =  $compara_db_adaptor->dbc->db_handle->selectrow_array("
    SELECT count(distinct root_id)
    FROM genomic_align_tree
    JOIN genomic_align USING (node_id)
    WHERE method_link_species_set_id = $mlss_id_epo AND dnafrag_id = $dnafrag_id");

    my $genomic_align_trees = $genomic_align_tree_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss_epo, $dnafrag);
    is(scalar @$genomic_align_trees, $num_epo, "Num genomic_align_trees");

    $genomic_align_trees = $genomic_align_tree_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss_epo, $dnafrag, undef, undef, 5);
    is(scalar @$genomic_align_trees, 5, "Num genomic_align_trees with limit");

    $genomic_align_trees = $genomic_align_tree_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss_epo, $dnafrag, $dnafrag_start, $dnafrag_end);
    is(scalar @$genomic_align_trees, 1, "Num genomic_align_trees with dnafrag_start and dnafrag_end");

    $genomic_align_trees = $genomic_align_tree_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss_epo, $dnafrag, undef, undef, undef, undef, 1);
    is(scalar @$genomic_align_trees, $num_epo, "Num genomic_align_trees with restrict");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignTreeAdaptor fetch_all_by_MethodLinkSpeciesSet_Slice method", sub {
    
    my $slice = $dnafrag->slice;

    my ($num_epo) =  $compara_db_adaptor->dbc->db_handle->selectrow_array("
    SELECT count(distinct root_id)
    FROM genomic_align_tree
    JOIN genomic_align USING (node_id)
    WHERE method_link_species_set_id = $mlss_id_epo AND dnafrag_id = $dnafrag_id");

    my $genomic_align_trees = $genomic_align_tree_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss_epo, $slice);
    is(scalar @$genomic_align_trees, $num_epo, "Num genomic_align_trees");

    $genomic_align_trees = $genomic_align_tree_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss_epo, $slice, 5);
    is(scalar @$genomic_align_trees, 5, "Num genomic_align_trees with limit");

    $genomic_align_trees = $genomic_align_tree_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss_epo, $slice, undef, undef, 1);
    is(scalar @$genomic_align_trees, $num_epo, "Num genomic_align_trees with restrict");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignTreeAdaptor fetch_by_GenomicAlignBlock method", sub {
    
    my $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);

    my $genomic_align_tree = $genomic_align_tree_adaptor->fetch_by_GenomicAlignBlock($genomic_align_block);
    isa_ok($genomic_align_tree,"Bio::EnsEMBL::Compara::GenomicAlignTree", "check object");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignTreeAdaptor fetch_by_genomic_align_block_id method", sub {
    
    my $genomic_align_tree = $genomic_align_tree_adaptor->fetch_by_genomic_align_block_id($genomic_align_block_id);
    isa_ok($genomic_align_tree,"Bio::EnsEMBL::Compara::GenomicAlignTree", "check object");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignTreeAdaptor::store", sub {

    my $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
    my $genomic_align_tree = $genomic_align_tree_adaptor->fetch_by_GenomicAlignBlock($genomic_align_block);
    my $genomic_aligns = $genomic_align_tree->get_all_genomic_aligns_for_node;

    foreach my $genomic_align_node (@{$genomic_align_tree->get_all_nodes}) {
        foreach my $this_genomic_align (@{$genomic_align_node->get_all_genomic_aligns_for_node}) {
            $this_genomic_align->genomic_align_block_id("");
        }
    }

    #Need to unset the genomic_align_block_id for both ancestral and modern gab (in the ga structure above). Something still wrong
    $multi->hide("compara", "genomic_align_tree", "genomic_align_block", "genomic_align");

    foreach my $table ("genomic_align_tree", "genomic_align_block", "genomic_align") {
        my $hidden_name = "_hidden_$table";
        my ($num_rows) =  $compara_db_adaptor->dbc->db_handle->selectrow_array("SELECT count(*) from $table");
        is($num_rows, 0, "Checking that there is no entries left in the <$table> table after hiding it");
    }

    $genomic_align_tree_adaptor->store($genomic_align_tree, 1);

    #lr_index_offset
    $multi->restore();
    done_testing();
};

done_testing();
