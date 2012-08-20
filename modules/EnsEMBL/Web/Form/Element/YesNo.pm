package EnsEMBL::Web::Form::Element::YesNo;

use strict;

use base qw(EnsEMBL::Web::Form::Element::Dropdown);

sub configure {
  ## @overrides
  my ($self, $params) = @_;

  my $options = delete $params->{'is_binary'} ? {0 => 'No', 1 => 'Yes'} : {'no' => 'No', 'yes' => 'Yes'};

  $self->SUPER::configure({%$params,
    'multiple'  => 0,
    'values'    => [ map {
      'value'     => $_,
      'caption'   => $options->{$_},
    }, sort keys %$options ]
  });
}

1;
