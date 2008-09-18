package EnsEMBL::Web::ViewConfig::idhistoryview;

use strict;

sub init {
  my ($view_config) = @_;
  $view_config->_set_defaults(qw(
    panel_tree    on
    panel_assoc   on
    status_idhistory_tree on
    image_width          800
    width 800
  ));
  $view_config->add_image_configs({qw(
    idhistoryview nodas
  )});
  $view_config->storable = 1;

}
1;
