package EnsEMBL::Web::DOM::Node::Element::H6;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element::H1);

sub node_name {
  ## @overrides
  return 'h6';
}

1;