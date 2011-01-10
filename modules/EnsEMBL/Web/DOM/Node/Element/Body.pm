package EnsEMBL::Web::DOM::Node::Element::Body;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'body';
}

sub w3c_appendable {
  ## @overrides
  my ($self, $child) = @_;
  return 
       $child->node_type == $self->ELEMENT_NODE && ($child->element_type == $self->ELEMENT_TYPE_BLOCK_LEVEL || $child->element_type == $self->ELEMENT_TYPE_SCRIPT)
    || $child->node_type == $self->COMMENT_NODE
    ? 1 : 0
  ;
}

1;