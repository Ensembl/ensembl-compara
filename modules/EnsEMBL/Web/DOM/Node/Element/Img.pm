package EnsEMBL::Web::DOM::Node::Element::Img;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'img';
}

sub can_have_child {
  ## @overrides
  return 0;
}

1;
