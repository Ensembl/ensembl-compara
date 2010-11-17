package EnsEMBL::Web::DOM::Node::Element::A;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'a';
}

sub _appendable {
  ## @overrides
  my ($self, $child) = @_;
  return
    $child->node_type == $self->TEXT_NODE
    ||
    $child->node_type == $self->ELEMENT_NODE
      &&
      $child->node_name =~ /^(img|span)$/
    ? 1
    : 0
  ;
}

1;