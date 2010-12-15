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
  $self->after($self->dom->create_element('span', {'inner_HTML' => ' '.$self->{'__shortnote'}})) if exists $self->{'__shortnote'};
  return $self->SUPER::render;
}

1;