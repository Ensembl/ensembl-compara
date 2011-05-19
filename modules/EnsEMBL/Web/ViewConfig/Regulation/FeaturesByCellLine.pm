# $Id$

package EnsEMBL::Web::ViewConfig::Regulation::FeaturesByCellLine;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Cell_line);

sub init {
  my $self = shift;
  
  $self->SUPER::init;
  $self->add_image_config('regulation_view') unless $self->hub->function eq 'Cell_line'; 
}

sub form_context {
  my $self = shift;
  
  $self->add_fieldset('Context');
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'context',
    label  => 'Context',
    values => [
      { value => '20',   name => '20bp'   },
      { value => '50',   name => '50bp'   },
      { value => '100',  name => '100bp'  },
      { value => '200',  name => '200bp'  },
      { value => '500',  name => '500bp'  },
      { value => '1000', name => '1000bp' },
      { value => '2000', name => '2000bp' },
      { value => '5000', name => '5000bp' }
    ]
  });

  $self->add_form_element({ type => 'YesNo', name => 'opt_highlight',    select => 'select', label => 'Highlight core region'            });
  $self->add_form_element({ type => 'YesNo', name => 'opt_empty_tracks', select => 'select', label => 'Show number of selected features' });
}

1;
