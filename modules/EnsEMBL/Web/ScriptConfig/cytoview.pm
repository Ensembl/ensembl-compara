package EnsEMBL::Web::ScriptConfig::cytoview;

use strict;
no strict 'refs';

sub init {
  my ($script_config ) = @_;

  $script_config->_set_defaults(qw(
    panel_ideogram    on
    panel_bottom      on
    image_width      800
    context        10000
  ));
  $script_config->add_image_configs({qw(
    cytoview das
  )});
  $script_config->storable = 1;
}
1;
