
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ClusterTagging;

use strict;
use warnings;

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self         = shift @_;
    my $gene_tree_id = $self->param_required('gene_tree_id');
    my $gene_tree    = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($gene_tree_id) or die "Could not fetch gene_tree with gene_tree_id='$gene_tree_id'";
    my $species_tree = $gene_tree->species_tree;

    #print Dumper $gene_tree;
    $self->param( 'gene_tree',    $gene_tree );
    $self->param( 'species_tree', $species_tree );
}

sub run {
    my $self = shift @_;

    # Extract stuff that is needed by several functions
    $self->_extract_tree_data();

    #get LCA (lowest common ancestor)
    my $lca_node = $self->_get_lca_node();
    $self->param( 'lca_node', $lca_node );

    #get taxonomic coverage
    my $taxonomic_coverage = $self->_get_taxonomic_coverage();
    $self->param( 'taxonomic_coverage', $taxonomic_coverage );

    #get ratio #species/#genes
    my $ratio_species_genes = $self->_get_ratio_species_genes();
    $self->param( 'ratio_species_genes', $ratio_species_genes );
}

sub write_output {
    my $self = shift;
    $self->param('gene_tree')->store_tag( 'lca_node_id',         $self->param('lca_node')->dbID );
    $self->param('gene_tree')->store_tag( 'taxonomic_coverage',  $self->param('taxonomic_coverage') );
    $self->param('gene_tree')->store_tag( 'ratio_species_genes', $self->param('ratio_species_genes') );
}

##########################################
#
# internal methods
#
##########################################

#Get the latest
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

sub _get_lca_node {
    my $self = shift;

    my $lca_node = $self->param('species_tree')->find_lca_of_GenomeDBs( [keys %{$self->param('genomes_list')}] );

    return $lca_node;
}

sub _get_taxonomic_coverage {
    my $self = shift;

    #get all genomes
    my $genomes_list = scalar( $self->param('genomes_list') );

    #get all leaves from MRCA
    my @leaves_ancestral = @{ $self->param('lca_node')->get_all_leaves() };
    $self->param( 'leaves_ancestral', \@leaves_ancestral );

    my $taxonomic_coverage = sprintf( "%.5f", ( keys( %{$genomes_list} )/scalar(@leaves_ancestral) ) );

    return $taxonomic_coverage;
}

sub _get_ratio_species_genes {
    my $self = shift;

    my $ratio_species_genes = sprintf( "%.5f", scalar( @{ $self->param('leaves_ancestral') } )/scalar( @{ $self->param('gene_tree_leaves') } ) );

    return $ratio_species_genes;
}

1;
