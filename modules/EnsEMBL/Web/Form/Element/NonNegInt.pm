package EnsEMBL::Web::Form::Element::NonNegInt;

use strict;

use base qw(EnsEMBL::Web::Form::Element::String);

use constant {
  VALIDATION_CLASS =>  '_nonnegint',
};

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  if ($params->{'max'}) {
    $params->{'shortnote'}  .= sprintf '(Maximum of %s)', $params->{'max'};
    $params->{'class'}      .= ' max_'.$params->{'max'};
  }
  $self->SUPER::configure($params);
}

1;