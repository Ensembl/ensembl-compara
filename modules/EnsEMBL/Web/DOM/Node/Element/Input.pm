package EnsEMBL::Web::DOM::Node::Element::Input;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

use constant {
  TYPE_ATTRIB => '',#override in child classes
};

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->set_attribute('type', $self->TYPE_ATTRIB);
  return $self;
}

sub type {
  ## Gets the type attribute of the input
  return shift->get_attribute('type');
}

sub node_name {
  ## @overrides
  return 'input';
}

sub form {
  ## Returns a reference to the form object that contains the input
  return shift->get_ancestor_by_tag_name('form');
}

sub disabled {
  ## Accessor for disabled attribute
  return shift->_access_attribute('disabled', @_);
}

1;