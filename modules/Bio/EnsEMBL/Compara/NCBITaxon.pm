=head1 NAME

NCBITaxon - DESCRIPTION of Object

=head1 DESCRIPTION
  
  An object that hold a node within a taxonomic tree.  Inherits from NestedSet.

=head1 CONTACT

  Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::NCBITaxon;

use strict;
use Bio::Species;
use Bio::EnsEMBL::Compara::NestedSet;

our @ISA = qw(Bio::EnsEMBL::Compara::NestedSet);

=head2 copy

  Arg [1]    : int $member_id (optional)
  Example    :
  Description: returns copy of object, calling superclass copy method
  Returntype :
  Exceptions :
  Caller     :

=cut

sub copy {
  my $self = shift;
  
  my $mycopy = $self->SUPER::copy;
  bless $mycopy, "Bio::EnsEMBL::Compara::NCBITaxon";
  
  $mycopy->ncbi_taxid($self->ncbi_taxid);
  $mycopy->rank($self->rank);

  return $mycopy;
}


sub ncbi_taxid {
  my $self = shift;
  my $value = shift;
  $self->node_id($value) if($value); 
  return $self->node_id;
}

sub rank {
  my $self = shift;
  $self->{'_rank'} = shift if(@_);
  return $self->{'_rank'};
}

sub print_node {
  my $self  = shift;
  printf("(%s", $self->node_id);
  printf(" %s", $self->rank) if($self->rank);
  print(")");
  printf("%s", $self->name) if($self->name);
  print("\n");
}

1;
