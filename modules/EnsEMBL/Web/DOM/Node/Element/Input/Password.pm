package EnsEMBL::Web::DOM::Node::Element::Input::Password;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element::Input);

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->set_attribute('type', 'password');
  return $self;
}

sub allowed_attributes {
  ## @overrides
  return [ @{ shift->SUPER::allowed_attributes }, qw(maxlength readonly size) ];
}

sub readonly {
  ## Accessor for readonly attribute
  return shift->_access_attribute('readonly', @_);
}

1;