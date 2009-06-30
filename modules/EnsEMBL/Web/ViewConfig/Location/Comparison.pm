package EnsEMBL::Web::ViewConfig::Location::Comparison;

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
    zoom_width    100
    context       1000
  ));
  $view_config->add_image_configs({qw(
    MultiIdeogram    nodas
    MultiTop         nodas
    MultiBottom      nodas
  )});
  $view_config->default_config = 'MultiBottom';
  $view_config->storable       = 1;
}

sub form {

}

1;
