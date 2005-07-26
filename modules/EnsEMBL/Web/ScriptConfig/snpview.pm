package EnsEMBL::Web::ScriptConfig::snpview;

use strict;
no strict 'refs';

sub init {
  my ($script_config ) = @_;

  $script_config->_set_defaults(qw(
    panel_genotypes  on
    panel_alleles    on
    panel_locations  on
    panel_individual off
    image_width      600
  ));
}
1;
