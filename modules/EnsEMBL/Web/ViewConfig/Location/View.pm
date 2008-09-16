package EnsEMBL::Web::ViewConfig::Location::View;

use strict;
no strict 'refs';

sub init {
### Used by Constructor
### init function called to set defaults for the passed
### {{EnsEMBL::Web::ScriptConfig}} object

  my( $script_config ) = @_;

  $script_config->_set_defaults(qw(
    panel_top       on
    panel_bottom    on
    panel_zoom     off
    zoom_width     100
    context       1000
  ));
  $script_config->add_image_configs({qw(
    contigviewtop    nodas
    contigviewbottom das
  )});
  $script_config->storable = 1;
}
1;
