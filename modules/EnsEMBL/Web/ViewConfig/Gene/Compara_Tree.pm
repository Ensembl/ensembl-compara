package EnsEMBL::Web::ViewConfig::genetreeview;

use strict;

sub init {
  my ($view_config) = @_;
  $view_config->_set_defaults(qw(
    image_width          800
    width 800
  ));
  $view_config->add_image_configs({qw(
    genetreeview nodas
  )});
  $view_config->storable = 1;

}
1;
