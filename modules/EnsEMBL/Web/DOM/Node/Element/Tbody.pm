package EnsEMBL::Web::DOM::Node::Element::Tbody;

## Status - Under Development

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'tbody';
}

#sub validate_attribute {}

sub allowed_attributes {
  ## @overrides
  return [ @{ shift->SUPER::allowed_attributes }, qw(align char charoff valign) ];
}

#sub mandatory_attributes {}
#sub can_have_child {}
#sub allowed_child_nodes {}

sub _appendable {
  ## @overrides
  my ($self, $child) = @_;
  return
    $child->node_type == $self->ELEMENT_NODE
    &&
    $child->node_name =~ /^tr$/
    ? 1
    : 0  
  ;
}

1;