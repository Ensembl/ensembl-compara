# $Id$

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
      { value => '10000',  name => '10kb'  },
      { value => '20000',  name => '20kb'  },
      { value => '50000',  name => '50kb'  },
      { value => '100000', name => '100kb' },
      { value => '500000', name => '500kb' }
    ]
  });
  
  # min r2
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'min_r2',
    label  => 'Minimum r^2 value',
    values => [
      { value => 0,    name => 0   },
      { value => 0.1,  name => 0.1 },
      { value => 0.2,  name => 0.2 },
      { value => 0.3,  name => 0.3 },
      { value => 0.4,  name => 0.4 },
      { value => 0.5,  name => 0.5 },
      { value => 0.6,  name => 0.6 },
      { value => 0.7,  name => 0.7 },
      { value => 0.8,  name => 0.8 },
      { value => 0.9,  name => 0.9 },
      { value => 1,    name => 1   },
    ]
  });
  
  # min d_prime
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'min_d_prime',
    label  => 'Minimum D\' value',
    values => [
      { value => 0,    name => 0   },
      { value => 0.1,  name => 0.1 },
      { value => 0.2,  name => 0.2 },
      { value => 0.3,  name => 0.3 },
      { value => 0.4,  name => 0.4 },
      { value => 0.5,  name => 0.5 },
      { value => 0.6,  name => 0.6 },
      { value => 0.7,  name => 0.7 },
      { value => 0.8,  name => 0.8 },
      { value => 0.9,  name => 0.9 },
      { value => 1,    name => 1   },
    ]
  });
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'min_p_log',
    label  => 'Minimum p-value (-log10) of associated phenotypes',
    values => [
      { value => 0,   name => '0 (show all)' },
      { value => 1,   name => 1              },
      { value => 2,   name => 2              },
      { value => 3,   name => 3              },
      { value => 4,   name => 4              },
      { value => 5,   name => 5              },
      { value => 6,   name => 6              },
      { value => 7,   name => 7              },
      { value => 8,   name => 8              },
      { value => 9,   name => 9              },
      { value => 10,  name => 10             },
      { value => 20,  name => 20             },
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
