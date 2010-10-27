package EnsEMBL::Web::Form::Element::Password;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw( EnsEMBL::Web::DOM::Node::Element::Input::Password EnsEMBL::Web::Form::Element::Text);

sub configure {
  ## @overrides the one in EnsEMBL::Web::Form::Element::Text
  my ($self, $params) = @_;

  $self->SUPER::configure($params);
  $self->set_attribute('class', $self->validation_types->{'password'})
    if exists $params->{'required'} && $params->{'required'} == 1;
}

1;