package EnsEMBL::Web::Form::Element::YesNo;

use strict;

use base qw(EnsEMBL::Web::Form::Element::Dropdown);

sub configure {
  ## @overrides
  my ($self, $params) = @_;

  $params->{'multiple'} = 0;
  $params->{'value'} = exists $params->{'value'} && ref($params->{'value'}) eq 'ARRAY'
    ? shift @{ $params->{'value'} }
    : $params->{'value'} || 0;
  
  $params->{'values'} = [{
    'value'     => 1,
    'caption'   => 'Yes'
  }, {
    'value'     => 0,
    'caption'   => 'No'
  }];
  $self->SUPER::configure($params);
}

1;