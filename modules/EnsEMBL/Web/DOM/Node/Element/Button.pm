package EnsEMBL::Web::DOM::Node::Element::Button;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'button';
}

sub disabled {
  ## Accessor for disabled attribute
  return shift->_access_attribute('disabled', @_);
}

1;