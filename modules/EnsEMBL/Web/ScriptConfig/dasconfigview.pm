package EnsEMBL::Web::ScriptConfig::dasconfview;

use strict;

sub init {
  my ($script_config) = @_;

  $script_config->_set_defaults(qw(
    contigview 1
    cytoview   1
    geneview   1
    protview   1
    transview  1
  ));
  $script_config->storable = 1;
}
1;
