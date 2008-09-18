package EnsEMBL::Web::ViewConfig::familyview;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    panel_table      on
    panel_other      on
    panel_ensembl    on
  ));
  $view_config->storable = 1;
}
1;
