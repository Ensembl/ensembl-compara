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


sub ncbi_taxid {
  my ($self,$value) = @_;
  return $self->node_id($value);
}

sub rank {
  my $self = shift;
  $self->{'_rank'} = shift if(@_);
  return $self->{'_rank'};
}

sub print_node {
  my $self  = shift;
  my $indent = shift;

  $indent = '' unless(defined($indent));
  printf("%s-%s(%d %s)\n", $indent, $self->name, $self->node_id, $self->rank);
}

1;
