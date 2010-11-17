package EnsEMBL::Web::DOM::Node::Element::Head;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'head';
}

1;