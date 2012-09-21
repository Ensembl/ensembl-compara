package EnsEMBL::Web::Form::Element::Checkbox;

use strict;

use base qw(EnsEMBL::Web::Form::Element::Checklist);

sub render {
  ## @overrides
  my $self = shift;

  $self->get_elements_by_class_name($self->CSS_CLASS_INNER_WRAPPER)->[0]->append_child($self->shortnote);

  return $self->SUPER::render(@_);
}

sub configure {
  ## @overrides
  my ($self, $params) = @_;

  $params->{'values'} = [{'value' => $params->{'value'}}];
  delete $params->{'value'} unless $params->{'checked'};
  $self->{'__shortnote'} = $params->{'shortnote'} if exists $params->{'shortnote'};

  $self->SUPER::configure($params);
}

1;