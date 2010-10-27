package EnsEMBL::Web::DOM::Node::Element::Table;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'table';
}

#sub validate_attribute {}
#sub allowed_attributes {}
#sub mandatory_attributes {}
#sub can_have_child {}
#sub allowed_child_nodes {}

sub _appendable {
  ## @overrides
  my ($self, $child) = @_;
  return
    $child->node_type == $self->ELEMENT_NODE
    &&
    $child->node_name =~ /^(caption|colgroup|tbody|tfoot|thead|tr)$/;
    ? 1
    : 0  
  ;
}

1;