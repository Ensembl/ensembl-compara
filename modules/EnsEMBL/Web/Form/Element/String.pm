package EnsEMBL::Web::Form::Element::String;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Input::Text
  EnsEMBL::Web::Form::Element
);

use constant {
  VALIDATION_CLASS =>  '_string', #override in child classes
};

sub render {
  ## @overrides
  my $self = shift;
  $self->after($self->dom->create_element('span', {'inner_HTML' => ' '.$self->{'__shortnote'}})) if exists $self->{'__shortnote'};
  return $self->SUPER::render;
}

sub configure {
  ## @overrides
  my ($self, $params) = @_;

  $params->{'class'} = join ' ', $params->{'class'} || '', $self->VALIDATION_CLASS || '', $params->{'required'} ? $self->CSS_CLASS_REQUIRED : $self->CSS_CLASS_OPTIONAL;

  exists $params->{$_} and $self->set_attribute($_, $params->{$_}) for qw(id name value size class maxlength);
  $params->{$_} and $self->$_(1) for qw(disabled readonly);

  $params->{'shortnote'} = '<strong title="Required field">*</strong> '.($params->{'shortnote'} || '') if $params->{'required'};
  $self->{'__shortnote'} = $params->{'shortnote'} if exists $params->{'shortnote'};
}

1;