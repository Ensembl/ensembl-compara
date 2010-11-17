package EnsEMBL::Web::DOM::Node::Element::Option;

use strict;

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

1;