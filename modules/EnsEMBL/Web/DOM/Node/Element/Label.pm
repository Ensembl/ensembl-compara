package EnsEMBL::Web::DOM::Node::Element::Label;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'label';
}

1;