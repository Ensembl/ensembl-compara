package EnsEMBL::Web::DOM::Node::Element::Th;

## Status - Under Development

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::DOM::Node::Element::Td);

sub node_name {
  ## @overrides
  return 'th';
}

1;