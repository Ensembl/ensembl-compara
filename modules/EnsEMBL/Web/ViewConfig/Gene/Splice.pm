# $Id$

package EnsEMBL::Web::ViewConfig::Gene::Splice;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->_set_defaults(qw(
    panel_image          on 
    context              100
    panel_transcript     on
    image_width          800
    reference            ),'',qw(
  ));

  $self->add_image_configs({qw(
    genespliceview_gene            nodas  
    genespliceview_transcript      nodas
  )});

  $self->default_config = 'genespliceview_transcript';
  $self->storable = 1;
}

1;
