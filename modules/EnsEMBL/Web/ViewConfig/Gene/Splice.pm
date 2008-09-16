package EnsEMBL::Web::ScriptConfig::genespliceview;

use strict;

sub init {
  my ($script_config) = @_;
  $script_config->_set_defaults(qw(
    context              100
    image_width          800
  ));
  $script_config->add_image_configs({qw(
    genesnpview_transcript nodas
    genesnpview_gene       nodas
    genesnpview_context    nodas
  )});
  $script_config->storable = 1;
}
1;
