package EnsEMBL::Web::Form::Element::Text;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Textarea
  EnsEMBL::Web::Form::Element::String
);

use constant {
  VALIDATION_CLASS =>  '_text',
};

sub configure {
  ## @overrides the one in EnsEMBL::Web::Form::Element::String
  my ($self, $params) = @_;
  
  $self->SUPER::configure($params);
  
  $self->set_attribute('rows', $params->{'rows'}) if exists $params->{'rows'};
  $self->set_attribute('cols', $params->{'cols'}) if exists $params->{'cols'};
  $self->remove_attribute('value');
  $self->remove_attribute('size');
  $self->remove_attribute('maxlength');
  $self->inner_HTML($params->{'value'}) if exists $params->{'value'};
}

1;