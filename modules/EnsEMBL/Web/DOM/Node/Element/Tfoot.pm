package EnsEMBL::Web::DOM::Node::Element::Tfoot;

## Status - Under Development

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::DOM::Node::Element::Tbody);

sub node_name {
  ## @overrides
  return 'tfoot';
}

1;