package EnsEMBL::Web::ViewConfig::Gene::Splice;

use strict;
use EnsEMBL::Web::Constants;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    panel_image          on 
    context              100
    panel_transcript     on
    image_width          800
    reference            ),'',qw(
  ));


  $view_config->add_image_configs({qw(
    genesnpview_gene            nodas  
    genesnpview_transcript      nodas
  )});

  $view_config->storable = 1;
}

sub form {
}
1;
