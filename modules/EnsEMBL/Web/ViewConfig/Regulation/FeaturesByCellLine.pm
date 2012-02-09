# $Id$

package EnsEMBL::Web::ViewConfig::Regulation::FeaturesByCellLine;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Cell_line);

sub init {
  my $self = shift;
  
  $self->add_image_config('regulation_view'); 
  $self->SUPER::init;
  $self->set_defaults({ opt_highlight => 'yes', context => 200 });
  $self->title = 'Details by cell line';
}

sub form_context {
  my $self = shift;
  
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

  $self->add_form_element({ type => 'YesNo', name => 'opt_highlight', select => 'select', label => 'Highlight core region' });
}

1;
