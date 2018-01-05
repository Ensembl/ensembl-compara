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

=head1 NAME

Bio::EnsEMBL::Compara::GeneTreeMember

=head1 DESCRIPTION

Currently the GeneTreeMember objects are used to represent the leaves of
the gene trees (whether they contain proteins or non-coding RNAs).

Each GeneTreeMember object is simultaneously a tree node (inherits from
GeneTreeNode) and an aligned member (inherits from AlignedMember).

The object only overrides a few methods from its parents, and does not have additional functionality.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::GeneTreeMember
  +- Bio::EnsEMBL::Compara::AlignedMember
  `- Bio::EnsEMBL::Compara::GeneTreeNode

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 SYNOPSIS

GeneTreeMember is a GeneTreeNode and an AlignedMember at the same time.
Refer to the documentation of those two objects.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::GeneTreeMember;

use strict;
use warnings;

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
  
  return $mycopy;
}


=head2 string_node (overrides default method in Bio::EnsEMBL::Compara::NestedSet)

  Arg [1]     : none
  Example     : $aligned_member->string_node();
  Description : Outputs the info for this GeneTreeMember. First, the node_id, the
                left and right indexes are printed, then the species name. If the
                gene member can be determined, the methods prints the stable_id,
                the display label and location of the gene member, otherwise the
                seq_member_id and stable_id of the object are printed.
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub string_node {
  my $self  = shift;
  my $str = sprintf("(%s %d,%d)", $self->node_id, $self->left_index, $self->right_index);
    if($self->genome_db_id and $self->adaptor) {
      $str .= sprintf(" %s", $self->genome_db->name) 
    }
  if(my $gene_member = $self->gene_member) {
    $str .= " ".$gene_member->stable_id;
    $str .= sprintf(" (%s)", $gene_member->display_label) if $gene_member->display_label;
    $str .= sprintf(" %s:%d-%d", $gene_member->dnafrag->name, $gene_member->dnafrag_start, $gene_member->dnafrag_end) if $gene_member->dnafrag_id;
  } elsif($self->stable_id) {
    $str .= sprintf(" (%d) %s", $self->seq_member_id, $self->stable_id);
  }
  $str .= "\n";
}



=head2 name (overrides default method in Bio::EnsEMBL::Compara::Graph::Node)

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

