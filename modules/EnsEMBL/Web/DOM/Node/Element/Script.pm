package EnsEMBL::Web::DOM::Node::Element::Script;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'script';
}

1;