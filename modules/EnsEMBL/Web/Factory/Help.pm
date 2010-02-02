package EnsEMBL::Web::Factory::Help;

use strict;

use base qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self        = shift;

  ## Create a very lightweight object, as the data required for a help page is very variable
  $self->DataObjects($self->new_object(
    'Help', {
      'records'       => undef,
    }, $self->__data
  ) ); 
}

1;
