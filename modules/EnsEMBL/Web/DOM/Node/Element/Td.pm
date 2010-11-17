package EnsEMBL::Web::DOM::Node::Element::Td;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'td';
}

sub _appendable {
  ## @overrides
  my ($self, $child) = @_;
  return
    $child->node_type == $self->TEXT_NODE
    ||
    $child->node_type == $self->COMMENT_NODE
    ||
    $child->node_type == $self->ELEMENT_NODE
      &&
      $child->node_name !~ /^(body|caption|col|colgroup|head|html|legend|li|optgroup|option|tbody|tfoot|th|thead|title|tr)$/
    ? 1
    : 0
  ;
}

1;