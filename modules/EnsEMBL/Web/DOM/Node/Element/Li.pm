package EnsEMBL::Web::DOM::Node::Element::Li;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'li';
}

1;