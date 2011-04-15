# $Id$

package EnsEMBL::Web::ViewConfig::Location::Chromosome;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  ### Used by Constructor
  ### init function called to set defaults for the passed
  ### {{EnsEMBL::Web::ViewConfig}} object
  
  my $self = shift;

  $self->_set_defaults(qw(
    panel_top      yes
    panel_zoom      no
    zoom_width    100
    context       1000
  ));
  
  $self->add_image_configs({qw(
    Vmapview      nodas
  )});
  
  $self->default_config = 'Vmapview';
  $self->storable       = 1;
}

1;
