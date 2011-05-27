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

sub rows {
  ## Gets an arrayref of all the rows inside the table
  return [ map { $_->node_name =~ /^t(.*)$/ ? $1 eq 'r' ? $_ : (@{$_->child_nodes}) : () } @{shift->child_nodes} ];
}

sub cells {
  ## Gets an arrayref of all the cells in the table
  return [ map {(@{$_->cells})} @{shift->rows} ];
}

1;