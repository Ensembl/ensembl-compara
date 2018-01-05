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
  <http://www.ensembl.org/Help/Contact>

=head1 NAME

Bio::EnsEMBL::Compara::SpeciesTree

=head1 DESCRIPTION

Header class for species trees

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::SpeciesTree
  +- Bio::EnsEMBL::Compara::NestedSet

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with an underscore (_).

=cut

package Bio::EnsEMBL::Compara::SpeciesTree;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);
use Bio::EnsEMBL::Compara::NestedSet;

use base ('Bio::EnsEMBL::Storable');



# Needed to enable BaseAdaptor::attach()
sub dbID {
    my $self = shift;
    return $self->root_id(@_);
}

######################################################
#
# Object variable methods
#
######################################################


=head2 multifurcate_tree

    Arg[1]      : -none-
    Example     : $tree->multifurcate_tree
    Description : Removes redundant nodes of a gene gain/loss tree
                  restoring original branch lengths.
                  These redundant nodes are originated during the CAFE analysis,
                  where a binary, ultrametric tree is needed instead of the original one
                  with multi-furcated nodes
    ReturnType  : undef (The object is updated)
    Exceptions  : none
    Caller      : general

=cut

sub multifurcate_tree {
    my ($self) = @_;

    my $NCBItaxon_Adaptor = $self->adaptor->db->get_NCBITaxon();
    for my $node (@{$self->root->get_all_nodes}) {
        next unless (defined $node->parent);
        my $mya = $node->get_divergence_time() || 0;
        for my $child (@{$node->children()}) {
            $child->distance_to_parent(int($mya));
        }

        if ($node->taxon_id eq $node->parent->taxon_id) {
            for my $child(@{$node->children}) {
                $node->parent->add_child($child);
                $child->distance_to_parent(int($mya));
            }
            $node->parent->merge_children($node);
            $node->parent->remove_nodes([$node]);
        }
    }
}


=head2 method_link_species_set_id

    Arg[1]      : (opt.) int
    Example     : my $mlss_id = $tree->method_link_species_set_id
    Description : Getter/Setter for the method_link_species_set associated with this analysis
    ReturnType  : scalar
    Exceptions  : none
    Caller      : general

=cut

sub method_link_species_set_id {
    my ($self, $mlss_id) = @_;
    if (defined $mlss_id) {
        $self->{'_method_link_species_set_id'} = $mlss_id;
    }
    return $self->{'_method_link_species_set_id'};
}

sub root_id {
    my ($self, $root_id) = @_;
    if (defined $root_id) {
        $self->{_root_id} = $root_id;
    }
    return $self->{_root_id};
}


sub label {
    my ($self, $label) = @_;
    if (defined $label) {
        $self->{_label} = $label;
    }
    return $self->{_label};
}


sub root {
    my ($self, $node) = @_;

    if (defined $node) {
        assert_ref($node, 'Bio::EnsEMBL::Compara::SpeciesTreeNode', 'node');
         $self->{'_root'} = $node;
    }

    if (not defined $self->{'_root'}) {
        if (defined $self->{'_root_id'} and defined $self->adaptor) {
            my $stn_adaptor = $self->adaptor->db->get_SpeciesTreeNodeAdaptor;
            $self->{'_root'} = $stn_adaptor->fetch_tree_by_root_id($self->{'_root_id'});
            $self->adaptor->_add_to_node_id_lookup($self);
        }
    }
    return $self->{'_root'};
}


sub get_genome_db_id_2_node_hash {
    my $self = shift;
    # Assumes the tree doesn't change
    return $self->{_genome_db_id_2_node_hash} if $self->{_genome_db_id_2_node_hash};
    my %h;
    $self->{_genome_db_id_2_node_hash} = \%h;
    foreach my $leaf (@{$self->root->get_all_nodes()}) {
        $h{$leaf->genome_db_id} = $leaf if $leaf->genome_db_id;
    }
    return \%h;
}

sub get_node_id_2_node_hash {
    my $self = shift;
    # Assumes the tree doesn't change
    return $self->{_node_id_2_node_hash} if $self->{_node_id_2_node_hash};
    my %h;
    $self->{_node_id_2_node_hash} = \%h;
    foreach my $leaf (@{$self->root->get_all_nodes()}) {
        $h{$leaf->node_id} = $leaf;
    }
    return \%h;
}


sub find_lca_of_GenomeDBs {
    my ($self, $genome_dbs) = @_;

    my $gdbid2stn = $self->get_genome_db_id_2_node_hash();
    my @species_tree_node_list = map {$gdbid2stn->{ref($_) ? $_->dbID : $_}} @$genome_dbs;

    return Bio::EnsEMBL::Compara::NestedSet->find_first_shared_ancestor_from_leaves( \@species_tree_node_list );
}


1;

