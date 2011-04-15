# $Id$

package EnsEMBL::Web::ViewConfig::Location::Multi;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->_set_defaults(qw(
    show_panels  both
    panel_zoom   no
    zoom_width   100
    context      1000
  ));
  
  $self->add_image_configs({qw(
    MultiTop     nodas
    MultiBottom  nodas
  )});
  
  $self->default_config = 'MultiBottom';
  $self->storable       = 1;
}

sub form {
  my $self = shift;
  
  $self->default_config = 'MultiTop' if $self->get('show_panels') eq 'top';
  
  $self->add_form_element({ 
    type   => 'DropDown', 
    name   => 'show_panels', 
    select => 'select', 
    label  => 'Displayed panel',
    values => [{
      value => 'both',
      name  => 'Both panels'
    }, {
      value => 'bottom',
      name  => 'Main panel only'
    }, {
      value => 'top',
      name  => 'Top panel only'
    }]
  });
}

1;
