package EnsEMBL::Web::Factory::Server;

use strict;

use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self      = shift;    
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." ) unless $self->database('core');
  
  $self->DataObjects( $self->new_object( 'Server', '', $self->__data ) );
}

1;
  
