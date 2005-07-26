package EnsEMBL::Web::ScriptConfig::status;

use strict;

sub init {
  my ($script_config) = @_;

  $script_config->_set_defaults(qw(
    panel_species on
  ));
}
1;
