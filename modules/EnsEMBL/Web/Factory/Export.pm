package EnsEMBL::Web::Factory::Export;

use strict;

use base qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self = shift;
  
  $self->DataObjects($self->new_object('Export', undef, $self->__data));
}

1;
