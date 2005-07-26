package EnsEMBL::Web::Factory::Static;

# my $factory  = EnsEMBL::Web::Proxy::Factory->new( 'Static', $input->options, $dbs );
#    $factory->createObjects(); 

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;

our @ISA = qw(  EnsEMBL::Web::Factory );

sub createObjects { 
  my $self      = shift;    
  my $database  = $self->database('core');
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." ) unless $database;
  
  $self->DataObjects( EnsEMBL::Web::Proxy::Object->new( 'Static', '', $self->data ) );
}

1;
  
