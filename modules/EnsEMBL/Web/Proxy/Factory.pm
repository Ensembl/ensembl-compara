package EnsEMBL::Web::Proxy::Factory;

use strict;
use EnsEMBL::Web::Proxy;
our @ISA = qw( EnsEMBL::Web::Proxy );

sub new {
  my( $class, $type, $data ) = @_;
  return $class->SUPER::new( 'Factory', $type, $data, '_feature_IDs'=>[], '_dataObjects' => [] );
}

1;
