package EnsEMBL::Web::ScriptConfig::genetreeview;

use strict;

sub init {
  my ($script_config) = @_;
  $script_config->_set_defaults(qw(
    image_width          800
    width 800
  ));
  $script_config->add_image_configs({qw(
    genetreeview nodas
  )});
  $script_config->storable = 1;

}
1;
