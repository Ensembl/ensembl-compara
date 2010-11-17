package EnsEMBL::Web::DOM::Node::Element::Thead;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Tbody);

sub node_name {
  ## @overrides
  return 'thead';
}

1;