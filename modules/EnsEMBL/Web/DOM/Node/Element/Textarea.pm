package EnsEMBL::Web::DOM::Node::Element::Textarea;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'textarea';
}

sub mandatory_attributes {
  ## @overrides
  return ['cols', 'rows'];
}

sub allowed_attributes {
  ## @overrides
  return [ @{ shift->SUPER::allowed_attributes }, qw(name value type accesskey tabindex cols rows readonly) ];
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
  ## Accessor of disabled attribute
  return shift->_access_attribute('disabled', @_);
}

1;