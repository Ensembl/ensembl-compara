package EnsEMBL::Web::DOM::Node::Element::Col;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'col';
}

1;