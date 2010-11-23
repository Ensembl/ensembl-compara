package EnsEMBL::Web::DOM::Node::Element::Input::Text;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Input);

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->set_attribute('type', 'text');
  return $self;
}

sub readonly {
  ## Accessor for readonly attribute
  return shift->_access_attribute('readonly', @_);
}

1;