# $Id$

package EnsEMBL::Web::ViewConfig::Variation::Summary;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->_set_defaults(qw(
    flank_size       400
    show_mismatches  yes
    display_type     align
  ));
  
  $self->storable = 1;
}

sub form {
  my $self = shift;

  # Add selection
  $self->add_fieldset('Flanking sequence');
  
  $self->add_form_element({
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Length of reference flanking sequence to display',
    name   => 'flank_size',
    values => [
      { value => '100',  name => '100bp'  },
      { value => '200',  name => '200bp'  },
      { value => '300',  name => '300bp'  },
      { value => '400',  name => '400bp'  },
      { value => '500',  name => '500bp'  },
      { value => '500',  name => '500bp'  },
      { value => '1000', name => '1000bp' },
    ]
  });  
  
  $self->add_form_element({
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Type of display when flanking sequence differs from reference',
    name   => 'display_type',
    values => [
      { value => 'align',  name => 'NW alignment' },
      { value => 'basic',  name => 'Basic' },
    ]
  });
  
  $self->add_form_element({
    type  => 'CheckBox',
    label => 'Highlight differences between source and reference flanking sequences',
    name  => 'show_mismatches',
    value => 'yes',
    raw   => 1,
  });
  
}

1;
