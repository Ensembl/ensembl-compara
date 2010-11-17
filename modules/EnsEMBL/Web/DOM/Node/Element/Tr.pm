package EnsEMBL::Web::DOM::Node::Element::Tr;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'tr';
}

sub _appendable {
  ## @overrides
  my ($self, $child) = @_;
  return
    $child->node_type == $self->ELEMENT_NODE
    &&
    $child->node_name =~ /^(td|th)$/
    ? 1
    : 0  
  ;
}

1;