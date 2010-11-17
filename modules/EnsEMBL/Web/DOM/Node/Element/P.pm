package EnsEMBL::Web::DOM::Node::Element::P;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'p';
}

1;