=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
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

Bio::EnsEMBL::Compara::GeneTreeMember

=head1 DESCRIPTION

Currently the GeneTreeMember objects are used to represent the leaves of
the gene trees (whether they contain proteins or non-coding RNas).

Each GeneTreeMember object is simultaneously a tree node (inherits from
GeneTreeNode) and an aligned member (inherits from AlignedMember).

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::GeneTreeMember
  +- Bio::EnsEMBL::Compara::AlignedMember
  `- Bio::EnsEMBL::Compara::GeneTreeNode

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

package Bio::EnsEMBL::Compara::GeneTreeMember;

use strict;

use base ('Bio::EnsEMBL::Compara::AlignedMember', 'Bio::EnsEMBL::Compara::GeneTreeNode');  # careful with the order; new() is currently inherited from Member-AlignedMember branch


=head2 copy

  Arg [1]     : none
  Example     : $copy = $gene_tree_member->copy();
  Description : Creates a new GeneTreeMember object from an existing one
  Returntype  : Bio::EnsEMBL::Compara::GeneTreeMember
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub copy {
  my $self = shift;
  
  my $mycopy = $self->Bio::EnsEMBL::Compara::GeneTreeNode::copy;
               $self->Bio::EnsEMBL::Compara::AlignedMember::copy($mycopy);     # we could rename this method into topup() as it is not needed by 'AlignedMember' class itself
  bless $mycopy, 'Bio::EnsEMBL::Compara::GeneTreeMember';
  
  return $mycopy;
}


=head2 string_node (overrides default method in Bio::EnsEMBL::Compara::NestedSet)

  Arg [1]     : none
  Example     : $aligned_member->string_node();
  Description : Outputs the info for this GeneTreeMember. First, the node_id, the
                left and right indexes are printed, then the species name. If the
                gene member can be determined, the methods prints the stable_id,
                the display label and location of the gene member, otherwise the
                member_id and stable_id of the object are printed.
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub string_node {
  my $self  = shift;
  my $str = sprintf("(%s %d,%d)", $self->node_id, $self->left_index, $self->right_index);
    if($self->genome_db_id and $self->adaptor) {
      my $genome_db = $self->genome_db;
      if (!defined($genome_db)) {
        $DB::single=1;1;
      }
      $str .= sprintf(" %s", $genome_db->name) 
    }
  if($self->gene_member) {
    $str .= sprintf(" %s %s %s:%d-%d",
      $self->gene_member->stable_id, $self->gene_member->display_label || '', $self->gene_member->chr_name,
      $self->gene_member->chr_start, $self->gene_member->chr_end);
  } elsif($self->stable_id) {
    $str .= sprintf(" (%d) %s", $self->member_id, $self->stable_id);
  }
  $str .= "\n";
}



=head2 name (overrides default method in Bio::EnsEMBL::Compara::Graph::CGObject)

  Arg [1]     : none
  Example     : $aligned_member->name();
  Description : Returns the stable_id of the object (from the Bio::EnsEMBL::Compara::Member object).
  Returntype  : string
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub name {
  my $self = shift;
  return $self->stable_id(@_);
}

1;

