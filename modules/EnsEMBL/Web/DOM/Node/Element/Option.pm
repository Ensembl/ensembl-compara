package EnsEMBL::Web::DOM::Node::Element::Option;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'option';
}

sub disabled {
  ## Accessor for disabled attribute
  return shift->_access_attribute('disabled', @_);
}

sub selected {
  ## Accessor for selected attribute
  return shift->_access_attribute('selected', @_);
}

sub allowed_attributes {
  ## @overrides
  return [ @{ shift->SUPER::allowed_attributes }, qw(selected value label disabled) ];
}

1;