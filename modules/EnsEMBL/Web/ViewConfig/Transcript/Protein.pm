package EnsEMBL::Web::ViewConfig::protview;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    panel_domain            on
    panel_other             on
    panel_variation         on
    show                    plain
    number                  off   
    das_sources),           []
  );
  $view_config->add_image_configs({qw(
    protview das
  )});
  $view_config->storable = 1;
}
1;
