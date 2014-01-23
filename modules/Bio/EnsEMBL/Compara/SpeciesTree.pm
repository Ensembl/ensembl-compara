=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=head1 SYNOPSIS


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

use base ('Bio::EnsEMBL::Storable');
use Bio::EnsEMBL::Utils::Exception;

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
        my $ncbiTaxon = $NCBItaxon_Adaptor->fetch_node_by_taxon_id($node->taxon_id);
        my $mya = $ncbiTaxon->get_tagvalue('ensembl timetree mya') || 0;
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

# From geneTreeNode
# sub root {
#     my $self = shift;

#     if (not defined $self->{'_root'}) {
#         if (defined $self->{'_root_id'} and defined $self->adaptor) {
#             # Loads all the nodes in one go
#             my $gtn_adaptor = $self->adaptor->db->get_GeneTreeNodeAdaptor;
#             $gtn_adaptor->{'_ref_tree'} = $self;
#             $self->{'_root'} = $gtn_adaptor->fetch_node_by_node_id($self->{'_root_id'});
#             delete $gtn_adaptor->{'_ref_tree'};

#         } else {
#             # Creates a new GeneTreeNode object
#             $self->{'_root'} = new Bio::EnsEMBL::Compara::GeneTreeNode;
#             $self->{'_root'}->tree($self);
#         }
#     }
#     return $self->{'_root'};
# }

sub root {
    my ($self, $node) = @_;
    ## TODO: Cache root
    if (defined $node) {
        throw("Expected Bio::EnsEMBL::Compara::SpeciesTreeNode, not a $node")
            unless ($node->isa("Bio::EnsEMBL::Compara::SpeciesTreeNode"));
         $self->{'_root'} = $node;
    }

    if (not defined $self->{'_root'}) {
        if (defined $self->{'_root_id'} and defined $self->adaptor) {
            my $stn_adaptor = $self->adaptor->db->get_SpeciesTreeNodeAdaptor;
#            $self->{'_root'} = $stn_adaptor->fetch_node_by_node_id($self->{'_root_id'});
            $self->{'_root'} = $stn_adaptor->fetch_tree_by_root_id($self->{'_root_id'});
        }
    }
    return $self->{'_root'};
}

# sub root {
#     my ($self, $node) = @_;
#     if (defined $node) {
#         throw("Expected Bio::EnsEMBL::Compara::SpeciesTreeNode, not a $node")
#             unless ($node->isa("Bio::EnsEMBL::Compara::SpeciesTreeNode"));
#         $self->{'_root'} = $node;
#     }
#     return $self->{'_root'};

# }

=head2 species_tree

    Arg[1]      : (opt.) <string> The species tree in newick format
    Example     : my $newick_tree = $tree->species_tree
    Description : Getter/Setter for the species tree in newick format
    ReturnType  : string
    Exceptions  : none
    Caller      : general

=cut

sub species_tree {
    my ($self, $species_tree) = @_;
    if (defined $species_tree) {
        $self->{'_species_tree'} = $species_tree;
    }
    return $self->{'_species_tree'};
}



1;

