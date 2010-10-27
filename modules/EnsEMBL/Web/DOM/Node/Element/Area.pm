package EnsEMBL::Web::DOM::Node::Element::Area;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'area';
}

#sub validate_attribute {}
#sub allowed_attributes {}
#sub mandatory_attributes {}
#sub can_have_child {}
#sub allowed_child_nodes {}
#sub appendable {}

1;