package EnsEMBL::Web::ViewConfig::Location::View;

use strict;
no strict 'refs';

sub init {
### Used by Constructor
### init function called to set defaults for the passed
### {{EnsEMBL::Web::ViewConfig}} object

  my( $view_config ) = @_;

  $view_config->_set_defaults(qw(
    panel_top       on
    panel_bottom    on
    panel_zoom     off
    image_width   1200
    zoom_width     100
    context       1000
  ));
  $view_config->add_image_configs({qw(
    contigviewtop    nodas
    contigviewbottom das
  )});
  $view_config->storable = 1;
}
1;
