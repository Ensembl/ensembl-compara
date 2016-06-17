=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::ViewConfig::Variation::LDPlot;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self     = shift;
  my %options  = EnsEMBL::Web::Constants::VARIATION_OPTIONS;
  my $defaults = {};

  foreach (keys %options) {
    my %hash = %{$options{$_}};
    $defaults->{lc $_} = $hash{$_}[0] for keys %hash;
  }

  $defaults->{'context'} = 50000;
  $defaults->{'ld_type'} = 'r2';
  $defaults->{'r2_mark'} = 0.8;
  $defaults->{'d_prime_mark'} = 0.8;
 
  $self->set_defaults($defaults);
  $self->image_config_type('ldmanplot');
  $self->title('Manhattan Plot');
}

sub extra_tabs {
  my $self = shift;
  my $hub  = $self->hub;
  
  return [
    'Select populations',
    $hub->url('Component', {
      action   => 'Web',
      function => 'SelectPopulation/ajax',
      time     => time,
      %{$hub->multi_params}
    })
  ];
}


sub init_form {
  my $self = shift;

  # Context
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'context',
    label  => 'Context (Region length)',
    values => [
      { value => 5000,   caption => '5kb'   },
      { value => 10000,  caption => '10kb'  },
      { value => 20000,  caption => '20kb'  },
      { value => 30000,  caption => '30kb'  },
      { value => 50000,  caption => '50kb'  },
      { value => 75000,  caption => '75kb'  },
      { value => 100000, caption => '100kb' }
    ]
  });

  # Track display
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'ld_type',
    label  => 'LD track type(s)',
    values => [
      { value => 'r2',      caption => 'r&sup2;'             },
      { value => 'd_prime', caption => "D'"                  },
      { value => 'both'   , caption => "both r&sup2; and D'" },
    ]
  });

  # r2 threshold
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'r2_mark',
    label  => 'r&sup2; horizontal mark',
    values => [
      { value => 0,   caption => 0   },
      { value => 0.1, caption => 0.1 },
      { value => 0.2, caption => 0.2 },
      { value => 0.3, caption => 0.3 },
      { value => 0.4, caption => 0.4 },
      { value => 0.5, caption => 0.5 },
      { value => 0.6, caption => 0.6 },
      { value => 0.7, caption => 0.7 },
      { value => 0.8, caption => 0.8 },
      { value => 0.9, caption => 0.9 },
      { value => 1,   caption => 1   },
    ]
  });

  # min d_prime
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'd_prime_mark',
    label  => 'D\' horizontal mark',
    values => [
      { value => 0,   caption => 0   },
      { value => 0.1, caption => 0.1 },
      { value => 0.2, caption => 0.2 },
      { value => 0.3, caption => 0.3 },
      { value => 0.4, caption => 0.4 },
      { value => 0.5, caption => 0.5 },
      { value => 0.6, caption => 0.6 },
      { value => 0.7, caption => 0.7 },
      { value => 0.8, caption => 0.8 },
      { value => 0.9, caption => 0.9 },
      { value => 1,   caption => 1   },
    ]
  });
}

1;
