package EnsEMBL::Web::DOM::Node::Element::Li;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'li';
}

1;