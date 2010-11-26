package EnsEMBL::Web::DOM::Node::Element::Legend;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'legend';
}

sub _appendable {
  ## @overrides
  my ($self, $child) = @_;
  return $child->node_type == $self->TEXT_NODE ? 1 : 0;
}

1;