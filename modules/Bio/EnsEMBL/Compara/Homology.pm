package Bio::EnsEMBL::Compara::Homology;

use strict;
use Bio::EnsEMBL::Compara::BaseRelation;

our @ISA = qw(Bio::EnsEMBL::Compara::BaseRelation);

=head2 new

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : Bio::EnsEMBL::Compara::Homology (but without members; caller has to fill using
               add_Member_Attribute)
  Exceptions : 
  Caller     : 

=cut

sub new {
  my($class,@args) = @_;
  
  my $self = $class->SUPER::new(@args);
  
  if (scalar @args) {
     #do this explicitly.
     my ($type) = $self->_rearrange([qw(TYPE)], @args);
      
      $type && $self->type($type);
  }
  
  return $self;
}   

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

