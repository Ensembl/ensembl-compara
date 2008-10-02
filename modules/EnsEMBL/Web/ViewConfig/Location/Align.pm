package EnsEMBL::Web::ViewConfig::Location::Align;

use strict;
use warnings;
no warnings 'uninitialized';
no strict 'refs';

sub init {
  my( $view_config ) = @_;

  $view_config->_set_defaults(qw(
    panel_ideo     yes 
    panel_top      yes 
    panel_zoom      no
    zoom_width     100
    context     100000
  ));
  $view_config->storable = 1;
  $view_config->add_image_configs({qw(
    alignsliceviewtop    nodas
    alignsliceviewbottom nodas
  )});
}

sub form {
  my( $view_config, $object ) = @_;

  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'panel_ideo', 'select' => 'select', 'label'  => 'Show ideogram panel' });
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'panel_top',  'select' => 'select', 'label'  => 'Show overview panel' });
 
}
1;
