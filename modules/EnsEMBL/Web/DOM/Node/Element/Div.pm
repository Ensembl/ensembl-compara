package EnsEMBL::Web::DOM::Node::Element::Div;

## Status - Under Development

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'div';
}

#sub validate_attribute {}
#sub allowed_attributes {}

sub _appendable {
  ## @overrides
  my ($self, $child) = @_;
  
  return
    $child->node_type eq $self->TEXT_NODE
    ||
    $child->node_type eq $self->COMMENT_NODE
    ||
    $child->node_type eq $self->ELEMENT_NODE
      &&
      $child->node_name !~ /^(body|caption|col|colgroup|head|html|li|optgroup|option|tbody|td|tfoot|th|thead|title|tr)$/
    ? 1
    : 0
  ;
}

1;