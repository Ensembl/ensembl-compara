package EnsEMBL::Web::DOM::Node::Element::H3;

## Status - Under Development

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::DOM::Node::Element::H1);

sub node_name {
  ## @overrides
  return 'h3';
}

1;