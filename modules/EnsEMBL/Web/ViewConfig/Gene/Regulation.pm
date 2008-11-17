package EnsEMBL::Web::ViewConfig::Gene::Regulation;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    image_width             800
    das_sources),           []
  );
  $view_config->add_image_configs({qw(
    generegview nodas
  )});
  $view_config->storable = 1;
}
1
