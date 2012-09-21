package EnsEMBL::Web::Form::Element::Password;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Input::Password
  EnsEMBL::Web::Form::Element::String
);

use constant {
  VALIDATION_CLASS =>  '_password',
};

sub render {
  ## @overrides
  my $self = shift;
  return $self->SUPER::render(@_).$self->shortnote->render(@_);
}

1;