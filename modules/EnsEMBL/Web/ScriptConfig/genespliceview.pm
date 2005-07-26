package EnsEMBL::Web::ScriptConfig::genespliceview;

use strict;

sub init {
  my ($script_config) = @_;
  $script_config->_set_defaults(qw(
    context              100
    image_width          700
  ));
}
1;
