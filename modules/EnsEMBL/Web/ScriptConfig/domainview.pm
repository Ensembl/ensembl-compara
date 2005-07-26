package EnsEMBL::Web::ScriptConfig::domainview;

use strict;

sub init {
  my ($script_config) = @_;

  $script_config->_set_defaults(qw(
    panel_table      on
  ));
}
1;
