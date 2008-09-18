package EnsEMBL::Web::ViewConfig::status;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    panel_species on
  ));
  $view_config->storable = 1;
}
1;
