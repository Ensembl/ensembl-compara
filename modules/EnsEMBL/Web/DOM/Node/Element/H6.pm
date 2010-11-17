package EnsEMBL::Web::DOM::Node::Element::H6;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::H1);

sub node_name {
  ## @overrides
  return 'h6';
}

1;