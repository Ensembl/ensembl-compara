package EnsEMBL::Web::Form::Element::Checkbox;

use strict;

use base qw(EnsEMBL::Web::Form::Element::Checklist);

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  $params->{'values'} = [{'value' => $params->{'value'}}];
  delete $params->{'value'} unless $params->{'checked'};

  $self->SUPER::configure($params);
}

1;