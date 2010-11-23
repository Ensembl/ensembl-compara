package EnsEMBL::Web::DOM::Node::Element::Input::Checkbox;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Input);

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->set_attribute('type', 'checkbox');
  return $self;
}

sub checked {
  ## Accessor for checked attribute
  return shift->_access_attribute('checked', @_);
}

1;