# $Id$

package EnsEMBL::Web::ViewConfig::Gene::GeneSpliceImage;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  $self->add_image_config('GeneSpliceView', 'nodas');
}

1;
