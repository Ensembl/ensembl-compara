package EnsEMBL::Web::DOM::Node::Element::Legend;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'legend';
}

sub can_have_child {
  ## @overrides
  return 0;
}

1;