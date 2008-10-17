package EnsEMBL::Web::ViewConfig::Gene::Summary;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    image_width             800
    das_sources),           []
  );
  $view_config->add_image_configs({qw(
    gene_summary nodas
  )});
  $view_config->default_config = 'gene_summary';
  $view_config->storable = 1;
}
1;
