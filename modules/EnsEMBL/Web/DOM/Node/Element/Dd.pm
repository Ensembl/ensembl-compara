package EnsEMBL::Web::DOM::Node::Element::Dd;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'dd';
}

1;