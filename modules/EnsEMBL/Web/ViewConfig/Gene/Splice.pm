package EnsEMBL::Web::ViewConfig::genespliceview;

use strict;

sub init {
  my ($view_config) = @_;
  $view_config->_set_defaults(qw(
    context              100
    image_width          800
  ));
  $view_config->add_image_configs({qw(
    genesnpview_transcript nodas
    genesnpview_gene       nodas
    genesnpview_context    nodas
  )});
  $view_config->storable = 1;
}

sub form {}
1;

