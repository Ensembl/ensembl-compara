package EnsEMBL::Web::DOM::Node::Element::Dt;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'dt';
}

1;