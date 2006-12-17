package EnsEMBL::Web::ScriptConfig::dotterview;

use strict;

sub init {
  my ($script_config) = @_;

  $script_config->_set_defaults(qw(
    w 5000
    t   48
    g    1
    h   -1
  ));
  $script_config->storable = 1;
}
1;
