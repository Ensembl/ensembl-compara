package EnsEMBL::Web::DOM::Node::Element::Dl;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'dl';
}

1;