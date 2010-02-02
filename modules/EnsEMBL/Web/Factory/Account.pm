package EnsEMBL::Web::Factory::Account;

use strict;

use base qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self          = shift;

  $self->DataObjects(
    $self->new_object(
     'Account', undef,
     $self->__data,
    ) 
  );

}

1;
