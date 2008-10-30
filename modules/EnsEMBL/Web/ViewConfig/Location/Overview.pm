package EnsEMBL::Web::ViewConfig::Location::Overview;

use strict;
use warnings;
no warnings 'uninitialized';

sub init {
  my ($view_config ) = @_;

  $view_config->_set_defaults(qw(
    context        10000
  ));
  $view_config->add_image_configs({qw(
    cytoview das
  )});
  $view_config->default_config = 'cytoview';
  $view_config->storable = 1;
}

sub form {}
1;
