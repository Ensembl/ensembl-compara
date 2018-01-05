
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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::FilterSmallClusters

=head1 SYNOPSIS

This runnable is used to:
    1 - get tags from all the flat (default) clusters 
    2 - filter out the unwanted clusters

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to filter out clusters that are:
1 - too small (min_num_members)
2 - too few species (min_num_species)
3 - low taxonomic coverage (min_taxonomic_coverage)
4 - low ratio of species ~ genes (min_ratio_species_genes)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::FilterSmallClusters;

use strict;
use warnings;

use Data::Dumper;

use base ('Bio::EnsEMBL::Hive::Process');
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;
    $self->param( 'gene_tree_id',      $self->param_required('gene_tree_id') );
    $self->param( 'gene_tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor );
    $self->param( 'gene_tree',         $self->param('gene_tree_adaptor')->fetch_by_dbID( $self->param('gene_tree_id') ) ) or die "Could not fetch gene_tree with gene_tree_id='" . $self->param('gene_tree_id');
    $self->param( 'gene_tree', $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID( $self->param('gene_tree_id') ) ) or die "Could not fetch gene_tree with gene_tree_id='" . $self->param('gene_tree_id');

    #Fetch tags
    $self->param( 'gene_count',          $self->param('gene_tree')->get_value_for_tag('gene_count') );
    $self->param( 'lca_node_id',         $self->param('gene_tree')->get_value_for_tag('lca_node_id') );
    $self->param( 'taxonomic_coverage',  $self->param('gene_tree')->get_value_for_tag('taxonomic_coverage') );
    $self->param( 'ratio_species_genes', $self->param('gene_tree')->get_value_for_tag('ratio_species_genes') );
}

sub run {
    my $self = shift @_;

    #Applying filters

    if ( $self->param('gene_count') > $self->param('min_num_members') ) {

        #if (    ($self->param('gene_count') < $self->param('min_num_members')) &&
        #    ($self->param('lca_node_id') < $self->param('min_num_species')) &&
        #    ($self->param('taxonomic_coverage') < $self->param('min_taxonomic_coverage')) &&
        #    ($self->param('ratio_species_genes') < $self->param('min_ratio_species_genes')) )  {

        #delete cluster from clusterset_id default and copy to filter_level_1
        $self->param('gene_tree_adaptor')->change_clusterset( $self->param('gene_tree'), "filter_level_1" );
    }

    print "Data:" . $self->param('gene_count') . "|" . $self->param('lca_node_id') . "|" . $self->param('taxonomic_coverage') . "|" . $self->param('ratio_species_genes') . "\n";
}

sub write_output {
    my $self = shift;
}

##########################################
#
# internal methods
#
##########################################

1;
