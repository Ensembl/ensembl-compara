package EnsEMBL::Web::DOM::Node::Element::Ol;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element::Ul);

sub node_name {
  ## @overrides
  return 'ol';
}

1;