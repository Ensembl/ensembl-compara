package EnsEMBL::Web::ScriptConfig::idhistoryview;

use strict;

sub init {
  my ($script_config) = @_;
  $script_config->_set_defaults(qw(
    image_width          900
    width 900
  ));
  $script_config->add_image_configs({qw(
    idhistoryview nodas
  )});
  $script_config->storable = 1;

}
1;
