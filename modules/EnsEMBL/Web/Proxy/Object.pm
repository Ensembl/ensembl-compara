package EnsEMBL::Web::Proxy::Object;

use strict;
use EnsEMBL::Web::Proxy;
our @ISA = qw( EnsEMBL::Web::Proxy );

# Usage my $gene = EnsEMBL::Web::Proxy::Object( 'Gene', @_ );

=head2 new

 Arg[1]      : object type
 Arg[2]      : ensembl object
 Arg[3]      : data hash ref
 Example     : EnsEMBL::Web::Proxy::Object( 'Gene', $gene, $data );
 Description : Instantiates the Proxy::Object, add all it's child
               objects
 Return type : the Proxy::Object if any of the child objects can
               instantiate.
=cut
sub new {
  my( $class, $type, $object, $data ) = @_;
  return $class->SUPER::new( 'Object', $type, $data, '_object'=> $object );
}

1;
