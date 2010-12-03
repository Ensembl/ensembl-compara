package EnsEMBL::Web::DOM::Node::Element::Input::Checkbox;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Input);

use constant {
  TYPE_ATTRIB => 'checkbox',
};

sub checked {
  ## Accessor for checked attribute
  return shift->_access_attribute('checked', @_);
}

1;