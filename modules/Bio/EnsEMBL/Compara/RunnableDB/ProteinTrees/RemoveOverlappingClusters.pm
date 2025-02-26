=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RemoveOverlappingClusters

=head1 SYNOPSIS

When we build strains gene trees we want to remove any clusters which do not contain
any strain-only species, since these clusters will also occur in the default run of the pipeline

We decide here to remove the redundant clusters prior to alignment/tree building

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RemoveOverlappingClusters;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DeleteOneTree');

sub fetch_input {
    my $self = shift;
    my $tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($self->param_required('gene_tree_id'));
    $self->param('gene_tree', $tree);
    $self->_extract_tree_data;
}

sub run {
    my $self = shift;

    my $non_overlapping_species_count = $self->_get_non_overlapping_species_count();
    if ( $non_overlapping_species_count > 0 ) {
        $self->input_job->autoflow(0);
        $self->complete_early("Cluster contains at least 1 strain-only species - do not delete");
    }
}

sub _extract_tree_data {
    my $self = shift;
    my $genomes_list;

    my $gene_tree_leaves = $self->param('gene_tree')->get_all_Members() || die "Could not get_all_Members for genetree: " . $self->param_required('gene_tree_id');

    #get all the genomes in the tree, store in a hash to avoid duplications.
    foreach my $leaf ( @{$gene_tree_leaves} ) {
        my $genomeDbId = $leaf->genome_db_id();
        $genomes_list->{$genomeDbId} = 1;
    }

    #storing refences in order to avoid multiple calls of the same functions.
    $self->param( 'genomes_list',     $genomes_list );
    $self->param( 'gene_tree_leaves', $gene_tree_leaves );
}

sub _get_non_overlapping_species_count {
    my $self = shift;
    
    my %genomes_in_cluster = %{$self->param('genomes_list')};
    my @overlapping_species = @{$self->param_required('overlapping_genomes')};
    
    foreach my $overlap_species_id ( @overlapping_species ) {
        $genomes_in_cluster{$overlap_species_id} = 0;
    }
    
    my $sum = 0;
    $sum += $_ for values %genomes_in_cluster;
    return $sum;
}

1;
