=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

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

=head2 taxon_id

  Description: Getter for the taxon ID (cf the NCBI database) of that node in the gene tree

=cut

sub taxon_id {
    my $self = shift;
    return $self->get_value_for_tag('taxon_id');
}


=head2 taxon

  Description: Getterfor the NCBITaxon object refering to the species containing that member

=cut

sub taxon {
  my $self = shift;

    unless (defined $self->{'_taxon'}) {
      unless (defined $self->taxon_id) {
        throw("can't fetch Taxon without a taxon_id");
      }
      my $NCBITaxonAdaptor = $self->adaptor->db->get_NCBITaxonAdaptor;
      $self->{'_taxon'} = $NCBITaxonAdaptor->fetch_node_by_taxon_id($self->taxon_id);
    }

  return $self->{'_taxon'};
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


=head2 lost_taxa

  Description: Returns the list of the taxon ID (cf the NCBI database) of the taxa
               that have lost that gene on the branch leading to the current node

=cut

sub lost_taxa {
    my $self = shift;
    return $self->get_all_values_for_tag('lost_taxon_id');
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
        -version => sprintf("%d.%d", $self->tree->version, $self->node_id),
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

1;

