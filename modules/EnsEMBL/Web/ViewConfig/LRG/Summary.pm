package EnsEMBL::Web::ViewConfig::LRG::Summary;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    image_width             800
    das_sources),           []
  );
  $view_config->add_image_configs({qw(
    lrg_summary das
  )});
  $view_config->default_config = 'lrg_summary';
  $view_config->storable = 1;
}

sub form {}
1;
