package EnsEMBL::Web::DOM::Node::Element::Table;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'table';
}

sub w3c_appendable {
  ## @overrides
  my ($self, $child) = @_;
  return $child->node_type == $self->ELEMENT_NODE && $child->node_name =~ /^(caption|colgroup|col|tbody|tfoot|thead|tr)$/ ? 1 : 0;
}

1;