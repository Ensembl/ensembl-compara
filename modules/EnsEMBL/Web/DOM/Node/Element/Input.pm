package EnsEMBL::Web::DOM::Node::Element::Input;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'input';
}

sub can_have_child {
  ## @overrides
  return 0;
}

sub allowed_attributes {
  ## @overrides
  return [ @{ shift->SUPER::allowed_attributes }, qw(name value type accesskey tabindex disabled) ];
}

sub validate_attribute {
  ## @overrides
  my ($self, $attrib_ref, $value_ref) = @_;
  
  if ($$attrib_ref eq 'disabled') {
    $$value_ref = 'disabled';
  }
  return $self->SUPER::validate_attribute($attrib_ref, $value_ref);
}

sub form {
  ## Returns a reference to the form object that contains the input
  my $self = shift;
  my $node = $self;
  while ($node) {
    $node = $node->parent_node;
    return $node if defined $node && $node->node_name eq 'form';
  }
  return undef;
}

sub disabled {
  ## Accessor for disabled attribute
  return shift->_access_attribute('disabled', @_);
}

1;