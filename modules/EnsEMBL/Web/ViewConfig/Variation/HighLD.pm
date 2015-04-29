=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::Variation::HighLD;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->set_defaults({
    max_distance    => 50000,
    min_r2          => 0.8,
    min_d_prime     => 0.8,
    only_phenotypes => 'no',
    min_p_log       => 0
  });

  $self->title = 'Linkage disequilibrium';
}

sub form {
  my $self = shift;
  
  # max distance
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'max_distance',
    label  => 'Maximum distance between variations',
    values => [
      { value => '10000',  caption => '10kb'  },
      { value => '20000',  caption => '20kb'  },
      { value => '50000',  caption => '50kb'  },
      { value => '100000', caption => '100kb' },
      { value => '500000', caption => '500kb' }
    ]
  });
  
  # min r2
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'min_r2',
    label  => 'Minimum r^2 value',
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
    name   => 'min_d_prime',
    label  => 'Minimum D\' value',
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
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'min_p_log',
    label  => 'Minimum p-value (-log10) of associated phenotypes',
    values => [
      { value => 0,  caption => '0 (show all)' },
      { value => 1,  caption => 1              },
      { value => 2,  caption => 2              },
      { value => 3,  caption => 3              },
      { value => 4,  caption => 4              },
      { value => 5,  caption => 5              },
      { value => 6,  caption => 6              },
      { value => 7,  caption => 7              },
      { value => 8,  caption => 8              },
      { value => 9,  caption => 9              },
      { value => 10, caption => 10             },
      { value => 20, caption => 20             },
    ]
  });
  
  $self->add_form_element({
    type  => 'CheckBox',
    label => 'Only display variations associated with phenotypes',
    name  => 'only_phenotypes',
    value => 'yes',
    raw   => 1,
  });
}

1;
