package EnsEMBL::Web::DOM::Node::Element::Ol;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Ul);

sub node_name {
  ## @overrides
  return 'ol';
}

1;