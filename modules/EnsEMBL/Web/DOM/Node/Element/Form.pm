package EnsEMBL::Web::DOM::Node::Element::Form;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'form';
}

sub allowed_attributes {
  ## @overrides
  return [ @{ shift->SUPER::allowed_attributes }, qw(accept accept-charset action method target enctype) ];
}

sub mandatory_attributes {
  ## @overrides
  return ['action'];
}

sub validate_attribute {
  ## @overrides
  my ($self, $attrib_ref, $value_ref) = @_;
  
  if ($$attrib_ref eq 'method') {
    $$value_ref = $$value_ref =~ /post/i ? 'post' : 'get';
  }
  elsif ($$attrib_ref eq 'name') {
    warn 'Attribute name for form is not valid for Strict DTD. Avoid using it.';
  }
  elsif ($$attrib_ref eq 'target') {
    warn 'Attribute target for form is deprecated. Avoid using it.';
  }
  return $self->SUPER::validate_attribute($attrib_ref, $value_ref);
}

#sub allowed_child_nodes {}
#sub appendable {}

1;