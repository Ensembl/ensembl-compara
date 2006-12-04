package EnsEMBL::Web::ScriptConfig::dasconfview;

use strict;

sub init {
  my ($script_config) = @_;

  $script_config->_set_defaults(qw());
  $script_config->storable = 1;
}
1;
