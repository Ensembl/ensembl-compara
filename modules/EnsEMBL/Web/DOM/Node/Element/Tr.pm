package EnsEMBL::Web::DOM::Node::Element::Tr;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'tr';
}

sub w3c_appendable {
  ## @overrides
  my ($self, $child) = @_;
  return $child->node_type == $self->ELEMENT_NODE && $child->node_name =~ /^t(r|h)$/ ? 1 : 0;
}

sub cells {
  ## Gets an arrayref of all the cells inside the row
  return shift->child_nodes;
}

1;
