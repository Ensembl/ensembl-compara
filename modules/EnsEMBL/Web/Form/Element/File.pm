package EnsEMBL::Web::Form::Element::File;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Input::File
  EnsEMBL::Web::Form::Element
);

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  exists $params->{$_} and $self->set_attribute($_, $params->{$_}) for qw(id name class);
  $self->set_attribute('class', $self->CSS_CLASS_REQUIRED)  if exists $params->{'required'};
  $self->disabled(1) if exists $params->{'disabled'} && $params->{'disabled'} == 1;
}

1;