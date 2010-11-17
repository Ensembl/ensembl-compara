package EnsEMBL::Web::DOM::Node::Element::Area;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'area';
}

sub can_have_child {
  ## @overrides
  return 0;
}

1;