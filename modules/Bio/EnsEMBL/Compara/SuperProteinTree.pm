=head1 NAME

ProteinTree - DESCRIPTION of Object

=head1 SYNOPSIS

   my $supertree_adaptor = Bio::EnsEMBL::Registry->get_adaptor
     ("Multi", "compara", "SuperProteinTree");
   my $super_protein_tree = $supertree_adaptor->fetch_by_Member_root_id($member);

=head1 DESCRIPTION

Specific subclass of NestedSet to add functionality when the leaves of
this tree are AlignedMember objects and the tree is a representation
of a protein multiple sequence alignment with a star topology.

=head1 CONTACT

  Contact Albert Vilella on implemetation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::SuperProteinTree;

use strict;
use Bio::EnsEMBL::Compara::BaseRelation;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;
use Bio::SimpleAlign;
use IO::File;

use Bio::EnsEMBL::Compara::ProteinTree;
our @ISA = qw(Bio::EnsEMBL::Compara::ProteinTree);


sub get_leaf_by_Member {
  my $self = shift;
  my $member = shift;

  if($member->isa('Bio::EnsEMBL::Compara::SuperProteinTree')) {
    return $self->find_leaf_by_node_id($member->node_id);
  } elsif ($member->isa('Bio::EnsEMBL::Compara::Member')) {
    return $self->find_leaf_by_name($member->get_longest_peptide_Member->stable_id);
  } else {
    die "Need a Member object!";
  }
}

sub get_SitewiseOmega_values {
  my $self = shift;

  $self->throw("method not defined by implementing" .
               " subclass of ProteinTree");
  return undef;
}

# Get the internal Ensembl GeneTree stable_id from the separate table
sub stable_id {
  my $self = shift;

  $self->throw("method not defined by implementing" .
               " subclass of ProteinTree");
  return undef;
}

1;
