package Bio::EnsEMBL::Compara::Homology;

use strict;
use Bio::EnsEMBL::Compara::BaseRelation;

our @ISA = qw(Bio::EnsEMBL::Compara::BaseRelation);

=head2 type

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub type {
  my $self = shift;
  $self->{'_type'} = shift if(@_);
  return $self->{'_type'};
}

1;

