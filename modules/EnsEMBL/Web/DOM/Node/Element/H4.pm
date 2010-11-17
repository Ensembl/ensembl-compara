package EnsEMBL::Web::DOM::Node::Element::H4;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::H1);

sub node_name {
  ## @overrides
  return 'h4';
}

1;