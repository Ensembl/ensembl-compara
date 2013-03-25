package EnsEMBL::Web::Factory::Help;

use strict;

use base qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self          = shift;

  $self->DataObjects(
    $self->new_object(
     'Help', undef,
     $self->__data,
    ) 
  );

}

1;
