package EnsEMBL::Web::ViewConfig::Location::Region;

use strict;
no strict 'refs';

sub init {
  my ($view_config ) = @_;

  $view_config->_set_defaults(qw(
    context        10000
  ));
  $view_config->add_image_configs({qw(
    cytoview das
  )});
  $view_config->storable = 1;
}
1;
