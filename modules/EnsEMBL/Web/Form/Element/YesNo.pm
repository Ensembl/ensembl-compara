package EnsEMBL::Web::Form::Element::YesNo;

use strict;

use base qw(EnsEMBL::Web::Form::Element::Dropdown);

sub configure {
  ## @overrides
  my ($self, $params) = @_;

  $params->{'multiple'} = 0;
  $params->{'value'} = exists $params->{'value'} && ref($params->{'value'}) eq 'ARRAY'
    ? shift @{ $params->{'value'} }
    : $params->{'value'} || '';
  
  $params->{'values'} = [{
    'value'     => 'yes',
    'caption'   => 'Yes',
    'selected'  => $params->{'value'} eq 'yes' ? 1 : 0,
  },{
    'value'     => 'no',
    'caption'   => 'No',
    'selected'  => $params->{'value'} eq 'no' ? 1 : 0,
  }];
  $self->SUPER::configure($params);
}

1;