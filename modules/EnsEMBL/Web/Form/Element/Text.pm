package EnsEMBL::Web::Form::Element::Text;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Textarea
  EnsEMBL::Web::Form::Element::String
);

use constant {
  VALIDATION_CLASS => '_text',

  DEFAULT_COLS     => 40,
  DEFAULT_ROWS     => 10,
};

sub render {
  ## @overrides
  my $self = shift;
  return $self->SUPER::render(@_).$self->shortnote->render(@_);
}

sub configure {
  ## @overrides the one in EnsEMBL::Web::Form::Element::String
  my ($self, $params) = @_;
  
  $self->SUPER::configure($params);
  
  $self->set_attribute('rows', $params->{'rows'} || $self->DEFAULT_ROWS);
  $self->set_attribute('cols', $params->{'cols'} || $self->DEFAULT_COLS);
  $self->remove_attribute('value');
  $self->remove_attribute('size');
  $self->remove_attribute('maxlength');
  $self->inner_HTML($params->{'value'}) if exists $params->{'value'};
}

1;