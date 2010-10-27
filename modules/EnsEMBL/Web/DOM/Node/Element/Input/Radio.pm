package EnsEMBL::Web::DOM::Node::Element::Input::Radio;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element::Input);

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->set_attribute('type', 'radio');
  return $self;
}

sub validate_attribute {
  ## @overrides
  my ($self, $attrib_ref, $value_ref) = @_;
  
  if ($$attrib_ref eq 'checked') {
    $$value_ref = 'checked';
  }
  return $self->SUPER::validate_attribute($attrib_ref, $value_ref);
}

sub checked {
  ## Accessor for checked attribute
  return shift->_access_attribute('checked', @_);
}

1;