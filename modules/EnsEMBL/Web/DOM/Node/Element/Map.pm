package EnsEMBL::Web::DOM::Node::Element::Map;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'map';
}

sub _appendable {
  ## @overrides
  my ($self, $child) = @_;
  return
    $child->node_type == $self->ELEMENT_NODE
      &&
      $child->node_name eq 'area'
    ? 1
    : 0
  ;
}
1;