# $Id$

package EnsEMBL::Web::ViewConfig::Location::View;

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
    image_width   1200
    zoom_width     100
    context       1000
  ));
  
  $self->add_image_configs({qw(
    contigviewtop    das
    contigviewbottom das
  )});
  
  $self->default_config = 'contigviewbottom';
  $self->storable       = 1;
}

sub form {
  my $self = shift;

  $self->add_form_element({ 'type' => 'YesNo', 'name' => 'panel_top', 'select' => 'select', 'label'  => 'Show overview panel' });
 
}
1;
