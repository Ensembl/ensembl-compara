package EnsEMBL::Web::DOM::Node::Element::H5;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::H1);

sub node_name {
  ## @overrides
  return 'h5';
}

1;