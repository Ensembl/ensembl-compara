package EnsEMBL::Web::ViewConfig::Transcript::ProteinSummary;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    das_sources),           []
  );
  $view_config->add_image_configs({qw(
    protview das
  )});
  $view_config->default_config = 'protview';
  $view_config->storable = 1;
}

1;
