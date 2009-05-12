package EnsEMBL::Web::ViewConfig::Location::View;

use strict;
use warnings;
no warnings 'uninitialized';

sub init {
### Used by Constructor
### init function called to set defaults for the passed
### {{EnsEMBL::Web::ViewConfig}} object

  my( $view_config ) = @_;

  $view_config->_set_defaults(qw(
    panel_top      yes
    panel_zoom      no
    image_width   1200
    zoom_width     100
    context       1000
  ));
  $view_config->add_image_configs({qw(
    contigviewtop    das
    contigviewbottom das
  )});
  $view_config->default_config = 'contigviewbottom';
  $view_config->storable       = 1;
}

sub form {
  my( $view_config, $object ) = @_;

  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'panel_top', 'select' => 'select', 'label'  => 'Show overview panel' });
 
}
1;
