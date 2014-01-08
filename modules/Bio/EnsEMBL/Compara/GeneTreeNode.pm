=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::GeneTreeNode

=head1 DESCRIPTION

Specific subclass of NestedSet to add functionality when the nodes of this tree
are GeneTreeMember objects and the tree is a representation of a gene derived
Phylogenetic tree

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::GeneTreeNode
  `- Bio::EnsEMBL::Compara::NestedSet

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::GeneTreeNode;

use strict;
use warnings;

use IO::File;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Compara::AlignedMemberSet;

use base ('Bio::EnsEMBL::Compara::NestedSet');

# Attributes / tags

=head2 species_tree_node

  Description: Getter for the node in the species tree the current node refers to

=cut

sub species_tree_node {
    my $self = shift;

    # If it is already there, return it
    if ($self->{_species_tree_node}) {
        return $self->{_species_tree_node};
    }

    ## Leaves don't have species_tree_node_id tag, so this value has to be taken from the GeneTreeMember (via its taxon_id);
    if ($self->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
        $self->{_species_tree_node} =  $self->tree->species_tree->root->find_nodes_by_field('taxon_id', $self->taxon_id)->[0];
    } elsif ( defined $self->get_value_for_tag('species_tree_node_id')) {
        $self->{_species_tree_node} = $self->adaptor->db->get_SpeciesTreeNodeAdaptor->fetch_node_by_node_id($self->get_value_for_tag('species_tree_node_id'));
    }

    return $self->{_species_tree_node};
}


=head2 _species_tree_node_id

  Description: Internal getter for the node ID of the species tree node related
               to the current gene tree node

=cut

sub _species_tree_node_id {
    my $self = shift;
    if ($self->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
        return $self->tree->species_tree->root->find_nodes_by_field('taxon_id', $self->taxon_id)->[0]->node_id;
    }

    return $self->get_value_for_tag('species_tree_node_id')
}


=head2 taxonomy_level

  Example    : $taxonomy_level = $homology->taxonomy_level();
  Description: getter of string description of homology taxonomy_level.
               Examples: 'Chordata', 'Euteleostomi', 'Homo sapiens'
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub taxonomy_level {
    my $self = shift;
    return undef unless $self->species_tree_node();
    return $self->species_tree_node()->node_name();
}


=head2 taxon_id

  Description: DEPRECATED: GeneTreeNode::taxon_id is deprecated and will be removed in e76. Please use GeneTreeNode::species_tree_node()->taxon_id() instead

=cut

sub taxon_id {  ## DEPRECATED
    my $self = shift;
    deprecate('GeneTreeNode::taxon_id is deprecated and will be removed in e76, Please use GeneTreeNode::species_tree_node()->taxon_id() instead');
    return undef unless $self->species_tree_node();
    return $self->species_tree_node()->taxon_id;
}


=head2 taxon

  Description: DEPRECATED: GeneTreeNode::taxon is deprecated and will be removed in e76, Please use GeneTreeNode::species_tree_node()->taxon() instead

=cut

sub taxon {  ## DEPRECATED
    my $self = shift;
    deprecate('GeneTreeNode::taxon is deprecated and will be removed in e76, Please use GeneTreeNode::species_tree_node()->taxon() instead');
    return undef unless $self->species_tree_node();
    return $self->species_tree_node()->taxon;
}


=head2 node_type

  Description: Getter for the node_type attribute. It shows the event that took place
               at that node. Currently, one of "duplication", "speciation", "dubious",
               and "gene_split"

=cut

sub node_type {
    my $self = shift;
    return $self->get_value_for_tag('node_type');
}

sub _newick_dup_code {
    my $self = shift;
    my $node_type = $self->node_type;
    return 'D=N' if ($node_type eq 'speciation');
    return 'DD=Y' if ($node_type eq 'dubious');
    return 'D=Y';
}


=head2 lost_taxa

  Description: Returns the list of the taxon ID (cf the NCBI database) of the taxa
               that have lost that gene on the branch leading to the current node

=cut

sub lost_taxa {
    my $self = shift;
    unless ($self->{_lost_species_tree_nodes}) {
        my @nodes;
        foreach my $dbID (@{$self->get_all_values_for_tag('lost_species_tree_node_id')}) {
            push @nodes, $self->adaptor->db->get_SpeciesTreeNodeAdaptor->fetch_node_by_node_id($dbID);
        }
        $self->{_lost_species_tree_nodes} = \@nodes;
    }
    return $self->{_lost_species_tree_nodes};
}


=head2 duplication_confidence_score

  Description: Returns the confidence score of the duplication node (between 0 and 1)
               "dubious" nodes always return 0, "speciation" nodes always return undef

=cut

sub duplication_confidence_score {
    my $self = shift;
    return $self->get_value_for_tag('duplication_confidence_score');
}


=head2 bootstrap

  Description: Returns the bootstrap value of that node (between 0 and 100)

=cut

sub bootstrap {
    my $self = shift;
    return $self->get_value_for_tag('bootstrap');
}





sub tree {
    my $self = shift;
    if (@_) {
        $self->{'_tree'} = shift;
    } elsif ((not defined $self->{'_tree'}) and (defined $self->adaptor) and (defined $self->{_root_id})) {
        $self->{'_tree'} = $self->adaptor->db->get_GeneTreeAdaptor->fetch_by_root_id($self->{_root_id});
    }
    return $self->{'_tree'};
}


# tweaked to take into account the GeneTree object
sub root {
    my $self = shift;
    if (defined $self->tree) {
        return $self->tree->root;
    } else {
        return $self->SUPER::root;
    }
}


=head2 release_tree

  Overview   : Removes the to/from GeneTree reference to
               allow freeing memory 
  Example    : $self->release_tree;
  Returntype : undef
  Exceptions : none
  Caller     : general

=cut

sub release_tree {
    my $self = shift;

    if (defined $self->{'_tree'}) {
        delete $self->{'_tree'}->{'_root'};
        delete $self->{'_tree'};
    }
    return $self->SUPER::release_tree;
}


#use Data::Dumper;

#sub string_node {
#    my $self = shift;
#    my $str = $self->SUPER::string_node;
#    if (defined $self->{'_tree'}) {
#        my $t = $self->{'_tree'};
#        $str = chop($str)." $t/root_id=".($self->{'_tree'}->root_id)."/".join("/", map { "$_ => ${$t}{$_}" } keys %$t)."\n";
#    }
#    return $str;
#}

sub get_leaf_by_Member {
  my $self = shift;
  my $member = shift;

  if($member->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {
    return $self->find_leaf_by_node_id($member->node_id);
  } elsif ($member->isa('Bio::EnsEMBL::Compara::GeneMember')) {
    return $self->find_leaf_by_name($member->get_canonical_SeqMember->stable_id);
  } elsif ($member->isa('Bio::EnsEMBL::Compara::SeqMember')) {
    return $self->find_leaf_by_name($member->gene_member->get_canonical_SeqMember->stable_id);
  } else {
    die "Need a Member object!";
  }
}

sub get_AlignedMemberSet {
    my $self = shift;
    my $set = Bio::EnsEMBL::Compara::AlignedMemberSet->new(
        -adaptor => $self->adaptor,
        -method_link_species_set_id => $self->tree->method_link_species_set_id,
        -stable_id => $self->tree->stable_id,
        -version => sprintf("%d.%d", $self->tree->version || 0, $self->node_id),
    );
    foreach my $member (@{$self->get_all_leaves}) {
        $set->add_Member($member) if $member->isa('Bio::EnsEMBL::Compara::GeneTreeMember');
    }
    return $set;
}

sub get_SimpleAlign {
    my $self = shift;
    return $self->get_AlignedMemberSet->get_SimpleAlign(@_);
}

# Takes a protein tree and creates a consensus cigar line from the
# constituent leaf nodes.
sub consensus_cigar_line {
    my $self = shift;
    return $self->get_AlignedMemberSet->consensus_cigar_line(@_);
}



=head2 remove_nodes_by_taxon_ids

  Arg [1]     : arrayref of taxon_ids
  Example     : my $ret_tree = $tree->remove_nodes_by_taxon_ids($taxon_ids);
  Description : Returns the tree with removed nodes in taxon_id list.
  Returntype  : Bio::EnsEMBL::Compara::GeneTreeNode object
  Exceptions  :
  Caller      : general
  Status      : At risk (behaviour on exceptions could change)

=cut

sub remove_nodes_by_taxon_ids {
  my $self = shift;
  my $species_arrayref = shift;

  my @tax_ids = @{$species_arrayref};
  # Turn the arrayref into a hash.
  my %tax_hash;
  map {$tax_hash{$_}=1} @tax_ids;

  my @to_delete;
  foreach my $leaf (@{$self->get_all_leaves}) {
    if (exists $tax_hash{$leaf->taxon_id}) {
      push @to_delete, $leaf;
    }
  }
  return $self->remove_nodes(\@to_delete);

}


=head2 keep_nodes_by_taxon_ids

  Arg [1]     : arrayref of taxon_ids
  Example     : my $ret_tree = $tree->keep_nodes_by_taxon_ids($taxon_ids);
  Description : Returns the tree with kept nodes in taxon_id list.
  Returntype  : Bio::EnsEMBL::Compara::GeneTreeNode object
  Exceptions  :
  Caller      : general
  Status      : At risk (behaviour on exceptions could change)

=cut


sub keep_nodes_by_taxon_ids {
  my $self = shift;
  my $species_arrayref = shift;

  my @tax_ids = @{$species_arrayref};
  # Turn the arrayref into a hash.
  my %tax_hash;
  map {$tax_hash{$_}=1} @tax_ids;

  my @to_delete;
  foreach my $leaf (@{$self->get_all_leaves}) {
    unless (exists $tax_hash{$leaf->taxon_id}) {
      push @to_delete, $leaf;
    }
  }
  return $self->remove_nodes(\@to_delete);

}


sub get_tagvalue {
    my $self = shift;
    my $tag = shift;
    my $default = shift;

    if (($tag eq 'taxon_id') or ($tag eq 'taxon_name')) {
        deprecate("The $tag tag has been deprecated. Please use species_tree_node() from the gene-tree node to get taxon information");
        if (not $self->has_tag($tag) and $self->has_tag('species_tree_node_id')) {
            $self->add_tag('taxon_id', $self->species_tree_node->taxon_id);
            $self->add_tag('taxon_name', $self->species_tree_node->node_name);
        }
    }
    return $self->SUPER::get_tagvalue($tag, $default);
}


1;

