package EnsEMBL::Web::Proxy::Object;

### NAME: Object.pm
### Wrapper around Proxiable Object

### PLUGGABLE: No - but enables plugins

### STATUS: At Risk
### (see parent) 

### DESCRIPTION
### (see parent) 

use strict;
use EnsEMBL::Web::Proxy;
our @ISA = qw( EnsEMBL::Web::Proxy );

sub new {
### c
### Constructs a proxy object - which wraps EnsEMBL::*::Object::$object s
### Takes three parameters - the type of object (Gene,Transcript,SNP etc),
### the underlying EnsEMBL object and the "common" data hash passed from

  my( $class, $type, $object, $data ) = @_;
  return $class->SUPER::new( 'Object', $type, $data, '_object'=> $object );
}

1;
