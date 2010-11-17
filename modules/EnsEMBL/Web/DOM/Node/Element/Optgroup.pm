package EnsEMBL::Web::DOM::Node::Element::Optgroup;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'optgroup';
}

1;