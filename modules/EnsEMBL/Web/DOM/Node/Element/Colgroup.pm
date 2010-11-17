package EnsEMBL::Web::DOM::Node::Element::Colgroup;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'colgroup';
}

1;