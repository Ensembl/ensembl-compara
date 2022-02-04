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

use Test::Most;

use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;


BEGIN {
    # Check module can be seen and compiled
    use_ok('Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::TransferAlignment');
}

# Load test DB
my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('update_msa_test');
my $dba = $multi_db->get_DBAdaptor('compara');
my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $dba );

# Make a copy of dnafrag, GAB, GA and GAT tables before editing them
$multi_db->save('compara', 'dnafrag', 'genomic_align', 'genomic_align_block', 'genomic_align_tree');

# Load required adaptors
my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
my $gab_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor();
my $gat_adaptor = $compara_dba->get_GenomicAlignTreeAdaptor();

# Previous and current MLSSs
my $prev_mlss_id = 1;
my $prev_mlss = $mlss_adaptor->fetch_by_dbID($prev_mlss_id);
my $curr_mlss_id = 3;
my $curr_mlss = $mlss_adaptor->fetch_by_dbID($curr_mlss_id);

# Extract all the information that is going to be transferred, offsetting the IDs by the expected difference
my $prev_gabs = $gab_adaptor->fetch_all_by_MethodLinkSpeciesSet($prev_mlss);
my $offset = ($curr_mlss_id - $prev_mlss_id) * 10**10;
my @projected_gab_ids = map { $_->dbID + $offset } @$prev_gabs;
my @prev_gas;
foreach my $genomic_align_block ( @$prev_gabs ) {
    push @prev_gas, @{ $genomic_align_block->get_all_GenomicAligns() };
}
my @projected_ga_ids = map { $_->dbID + $offset } @prev_gas;
my $prev_gats = $gat_adaptor->fetch_all_by_MethodLinkSpeciesSet($prev_mlss);
my @projected_gat_ids;
foreach my $genomic_align_tree ( @$prev_gats ) {
    foreach my $node ( @{ $genomic_align_tree->get_all_nodes() } ) {
        push @projected_gat_ids,
            [ $node->node_id + $offset, ($node->has_parent) ? $node->parent->node_id + $offset : undef, $node->root->node_id + $offset ];
    }
}
# Sort the genomic align trees since the order returned by get_all_nodes() is not ensured
@projected_gat_ids = sort {$a->[0] <=> $b->[0]} @projected_gat_ids;
# Get only the ancestral dnafrags, since these are the only ones "attached" to a MLSS
my @prev_anc_dnafrags = grep { $_->genome_db->name eq 'ancestral_sequences' } map { $_->dnafrag() } @prev_gas;
# The MLSS ID is also included in the ancestral dnafrag name
my @projected_anc_df_info = map { ( $_->dbID + $offset, $_->name =~ s/\_${prev_mlss_id}\_/_${curr_mlss_id}_/r ) } @prev_anc_dnafrags;

standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::TransferAlignment',  # Module
    {  # Input param hash
        'compara_db'    => $compara_dba->url,
        'method_type'   => $curr_mlss->method->type,
        'mlss_id'       => $curr_mlss_id,
        'prev_mlss_id'  => $prev_mlss_id,
    }
);

# Test GABs transferred correctly
my $curr_gabs = $gab_adaptor->fetch_all_by_MethodLinkSpeciesSet($curr_mlss);
my @curr_gab_ids = map { $_->dbID } @$curr_gabs;
is_deeply( \@curr_gab_ids, \@projected_gab_ids, 'Genomic align blocks transferred with the right ID offset' );

# Test GAs transferred correctly
my @curr_gas;
foreach my $genomic_align_block ( @$curr_gabs ) {
    push @curr_gas, @{ $genomic_align_block->get_all_GenomicAligns() };
}
my @curr_ga_ids = map { $_->dbID } @curr_gas;
is_deeply( \@curr_ga_ids, \@projected_ga_ids, 'Genomic aligns transferred with the right ID offset' );

# Test GATs transferred correctly
my $curr_gats = $gat_adaptor->fetch_all_by_MethodLinkSpeciesSet($curr_mlss);
my @curr_gat_ids;
foreach my $genomic_align_tree ( @$curr_gats ) {
    foreach my $node ( @{ $genomic_align_tree->get_all_nodes() } ) {
        push @curr_gat_ids,
            [ $node->node_id, ($node->has_parent) ? $node->parent->node_id : undef, $node->root->node_id ];
    }
}
# Sort the genomic align trees since the order returned by get_all_nodes() is not ensured
@curr_gat_ids = sort {$a->[0] <=> $b->[0]} @curr_gat_ids;
is_deeply( \@curr_gat_ids, \@projected_gat_ids, 'Genomic align trees transferred with the right ID offset' );

# Test ancestral dnafrags transferred correctly
my @curr_anc_dnafrags = grep { $_->genome_db->name eq 'ancestral_sequences' } map { $_->dnafrag() } @curr_gas;
my @curr_anc_df_info = map { ( $_->dbID, $_->name ) } @curr_anc_dnafrags;
is_deeply( \@curr_anc_df_info, \@projected_anc_df_info, 'Ancestral dnafrags transferred with the right ID offset and name' );

# Restore dnafrag, GAB, GA and GAT tables
$multi_db->restore('compara', 'dnafrag', 'genomic_align', 'genomic_align_block', 'genomic_align_tree');

done_testing();
