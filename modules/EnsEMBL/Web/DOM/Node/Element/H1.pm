package EnsEMBL::Web::DOM::Node::Element::H1;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'h1';
}

1;