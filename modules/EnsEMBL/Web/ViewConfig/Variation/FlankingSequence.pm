# $Id$

package EnsEMBL::Web::ViewConfig::Variation::FlankingSequence;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    flank_size      => 400,
    snp_display     => 'yes',
    line_numbering  => 'sequence',
    select_sequence => 'both',
  });

  $self->title = 'Flanking sequence';
}

sub form {
  my $self = shift;
  
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
    select => 'select',
    name   => 'select_sequence',
    label  => 'Sequence selection',
    values => [
      { value => 'both',  name => "Upstream and downstream sequences"   },
      { value => 'up',   name => "Upstream sequence only (5')"   },
      { value => 'down', name => "Downstream sequence only (3')" },
    ]
  });
  
  $self->add_form_element({ 
    type   => 'YesNo', 
    name   => 'snp_display', 
    select => 'select', 
    label  => 'Show variations in flanking sequence'
  });
}

1;
