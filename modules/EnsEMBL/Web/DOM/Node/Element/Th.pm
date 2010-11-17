package EnsEMBL::Web::DOM::Node::Element::Th;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Td);

sub node_name {
  ## @overrides
  return 'th';
}

1;