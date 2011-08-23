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
  return $self->SUPER::render(@_).$self->render_shortnote(@_);
}

sub configure {
  ## @overrides
  my ($self, $params) = @_;

  $params->{'class'} = join ' ', $params->{'class'} || '', $self->VALIDATION_CLASS || '', $params->{'required'} ? $self->CSS_CLASS_REQUIRED : $self->CSS_CLASS_OPTIONAL;
  
  exists $params->{'value'} and $params->{'value'} = $self->encode_htmlentities($params->{'value'}) unless $params->{'is_encoded'};

  exists $params->{$_} and $self->set_attribute($_, $params->{$_}) for qw(id name value size class maxlength);
  $params->{$_} and $self->$_(1) for qw(disabled readonly);

  $params->{'shortnote'} = '<strong title="Required field">*</strong> '.($params->{'shortnote'} || '') if $params->{'required'};
  $self->{'__shortnote'} = $params->{'shortnote'} if exists $params->{'shortnote'};
}

1;