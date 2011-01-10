package EnsEMBL::Web::DOM::Node::Element::P;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'p';
}

sub w3c_appendable {
  ## @overrides
  my ($self, $child) = @_;
  return 
       $child->node_type == $self->ELEMENT_NODE && ($child->element_type == $self->ELEMENT_TYPE_INLINE || $child->element_type == $self->ELEMENT_TYPE_SCRIPT)
    || $child->node_type == $self->TEXT_NODE
    || $child->node_type == $self->COMMENT_NODE
    ? 1 : 0
  ;
}

1;