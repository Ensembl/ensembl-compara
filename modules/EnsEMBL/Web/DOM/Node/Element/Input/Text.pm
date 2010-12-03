package EnsEMBL::Web::DOM::Node::Element::Input::Text;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Input);

use constant {
  TYPE_ATTRIB => 'text',
};

sub readonly {
  ## Accessor for readonly attribute
  return shift->_access_attribute('readonly', @_);
}

1;