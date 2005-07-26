package EnsEMBL::Web::Factory::Server;

use strict;

use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;

our @ISA = qw(  EnsEMBL::Web::Factory );

sub createObjects { 
  my $self      = shift;    
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." ) unless $self->database('core');
  
  $self->DataObjects( EnsEMBL::Web::Proxy::Object->new( 'Server', '', $self->__data ) );
}

1;
  
