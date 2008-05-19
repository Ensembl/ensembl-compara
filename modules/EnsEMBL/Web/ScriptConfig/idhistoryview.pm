package EnsEMBL::Web::ScriptConfig::idhistoryview;

use strict;

sub init {
  my ($script_config) = @_;
  $script_config->_set_defaults(qw(
    panel_tree    on
    panel_assoc   on
    status_idhistory_tree on
    image_width          800
    width 800
  ));
  $script_config->add_image_configs({qw(
    idhistoryview nodas
  )});
  $script_config->storable = 1;

}
1;
