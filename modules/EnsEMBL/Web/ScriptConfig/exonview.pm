package EnsEMBL::Web::ScriptConfig::exonview;

use strict;

sub init {
  my ($script_config) = @_;

  $script_config->_set_defaults(qw(
    panel_exons      on
    panel_supporting on
  ));
}
1;
