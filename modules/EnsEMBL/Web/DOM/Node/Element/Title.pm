package EnsEMBL::Web::DOM::Node::Element::Title;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Title);

sub node_name {
  ## @overrides
  return 'title';
}

1;