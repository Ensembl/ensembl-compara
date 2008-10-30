package EnsEMBL::Web::ViewConfig::dotterview;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    w 5000
    t   48
    g    1
    h   -1
  ));
  $view_config->storable = 1;
}

sub form {}
1;
