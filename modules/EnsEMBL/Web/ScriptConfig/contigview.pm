package EnsEMBL::Web::ScriptConfig::contigview;

use strict;
no strict 'refs';

sub init {
  my( $script_config ) = @_;

  $script_config->_set_defaults(qw(
    panel_ideogram on
    panel_top      on
    panel_bottom   on
    panel_zoom     off
    zoom_width     100
    image_width    700
    context    1000
  ));
  $script_config->storable = 1;
}
1;
