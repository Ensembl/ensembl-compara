package EnsEMBL::Web::ScriptConfig::familyview;

use strict;

sub init {
  my ($script_config) = @_;

  $script_config->_set_defaults(qw(
    panel_table      on
    panel_other      on
    panel_ensembl    on
  ));
  $script_config->storable = 1;
}
1;
