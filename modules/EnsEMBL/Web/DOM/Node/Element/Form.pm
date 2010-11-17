package EnsEMBL::Web::DOM::Node::Element::Form;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'form';
}

1;