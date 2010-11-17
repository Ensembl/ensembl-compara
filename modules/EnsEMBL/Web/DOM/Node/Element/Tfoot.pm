package EnsEMBL::Web::DOM::Node::Element::Tfoot;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Tbody);

sub node_name {
  ## @overrides
  return 'tfoot';
}

1;