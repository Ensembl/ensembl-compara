package EnsEMBL::Web::Proxy::Factory;

use strict;
use EnsEMBL::Web::Proxy;
our @ISA = qw( EnsEMBL::Web::Proxy );

sub new {
### c
### Constructs a proxy factory - which wraps EnsEMBL::*::Factory::$object s
### Takes two parameters - the type of object (Gene,Transcript,SNP etc),
### and the "common" data hash

  my( $class, $type, $data ) = @_;
  return $class->SUPER::new( 'Factory', $type, $data, '_feature_IDs'=>[], '_dataObjects' => [] );
}

1;
