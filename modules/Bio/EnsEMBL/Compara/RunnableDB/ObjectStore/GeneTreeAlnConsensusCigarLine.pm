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

Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeAlnConsensusCigarLine

=head1 DESCRIPTION

This eHive Runnable prepares a data-structure holding the consensus cigar-lines
of all the internal nodes of a given GeneTree.
The data are used by the web-site

Required parameters:
 - gene_tree_id: the root_id of the GeneTree

Branch events:
 - #1: autoflow on success (eHive default)

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeAlnConsensusCigarLine;

use strict;
use warnings;

use JSON;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


## Fetch the gene-tree from the database
sub fetch_input {
    my $self = shift @_;

    $self->dbc and $self->dbc->disconnect_if_idle();

    my $gene_tree_id    = $self->param_required('gene_tree_id');
    my $tree_adaptor    = $self->compara_dba->get_GeneTreeAdaptor;
    my $gene_tree       = $tree_adaptor->fetch_by_dbID( $gene_tree_id ) or die "Could not fetch gene_tree with gene_tree_id='$gene_tree_id'";

    # Preload everything to make the analysis faster
    $gene_tree->preload;
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->compara_dba->get_SequenceAdaptor, undef, $gene_tree);

    # Pass it to run()
    $self->param('gene_tree', $gene_tree);
}

## Compute consensus cigar-lines
#the LCA-pruned tree and convert both to JSON
sub run {
    my $self = shift @_;

    $self->dbc and $self->dbc->disconnect_if_idle();

    my %ccl;
    foreach my $node (@{$self->param('gene_tree')->get_all_nodes}) {
        # Only the internal nodes
        $ccl{$node->node_id} = $node->consensus_cigar_line unless $node->is_leaf;
    }

    # Serialize in JSON
    my $jf = JSON->new()->pretty(0);
    my $ccl_json = $jf->encode(\%ccl);
    $self->param('ccl_json', $ccl_json);
}

## Store the data in the database
sub write_output {
    my $self = shift @_;

    $self->dbc and $self->dbc->disconnect_if_idle();

    $self->compara_dba->get_GeneTreeObjectStoreAdaptor->store($self->param('gene_tree_id'), 'consensus_cigar_line', $self->param('ccl_json'))
        || die "Nothing was stored in the database for gene_tree_id=".$self->param('gene_tree_id');
}

1;
