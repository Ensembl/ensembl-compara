# $Id$

package EnsEMBL::Web::ViewConfig::Gene::GeneSNPImage;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Gene::GeneSNPTable);

sub init {
  my $self = shift;
  $self->SUPER::init;
  $self->add_image_config('GeneSNPView', 'nodas');
}

1;
