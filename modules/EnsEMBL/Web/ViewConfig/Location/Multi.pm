package EnsEMBL::Web::ViewConfig::Location::Multi;

use strict;
use warnings;
no warnings 'uninitialized';

sub init {
  my $view_config = shift;

  $view_config->_set_defaults(qw(
    panel_top       yes
    panel_zoom      no
    zoom_width      100
    context         1000
  ));
  
  $view_config->add_image_configs({qw(
    MultiTop      nodas
    MultiBottom   nodas
  )});
  
  $view_config->default_config = 'MultiBottom';
  $view_config->storable = 1;
}

sub form {
  my $view_config = shift;
  
  $view_config->add_form_element({ 
    type   => 'YesNo', 
    name   => 'panel_top', 
    select => 'select', 
    label  => 'Show overview panel'
  });
}

1;
