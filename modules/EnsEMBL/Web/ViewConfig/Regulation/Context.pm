package EnsEMBL::Web::ViewConfig::Regulation::Context;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    image_width             800
    das_sources),           []
  );
  $view_config->add_image_configs({qw(
    reg_summary das
  )});
  $view_config->default_config = 'reg_summary';
  $view_config->storable = 1;
}

sub form {}
1;

