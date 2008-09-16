package EnsEMBL::Web::ViewConfig::Location::Region;

use strict;
no strict 'refs';

sub init {
  my ($script_config ) = @_;

  $script_config->_set_defaults(qw(
    context        10000
  ));
  $script_config->add_image_configs({qw(
    cytoview das
  )});
  $script_config->storable = 1;
}
1;
