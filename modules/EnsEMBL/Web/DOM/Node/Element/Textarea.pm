package EnsEMBL::Web::DOM::Node::Element::Textarea;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'textarea';
}

sub form {
  ## Returns a reference to the form object that contains the input
  return shift->get_ancestor_by_tag_name('form');
}

sub disabled {
  ## Accessor of disabled attribute
  return shift->_access_attribute('disabled', @_);
}

1;