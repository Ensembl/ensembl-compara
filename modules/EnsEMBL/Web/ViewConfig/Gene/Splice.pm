# $Id$

package EnsEMBL::Web::ViewConfig::Gene::Splice;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->_set_defaults(qw(
    panel_image      on 
    context          100
    panel_transcript on
    image_width      800
    reference),      ''
  );

  $self->add_image_configs({qw(
    GeneSpliceView nodas
  )});

  $self->default_config = 'GeneSpliceView';
  $self->storable       = 1;
}

1;
