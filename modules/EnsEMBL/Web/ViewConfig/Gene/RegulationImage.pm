# $Id$

package EnsEMBL::Web::ViewConfig::Gene::RegulationImage;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  $self->add_image_config('generegview');
  $self->title = 'Regulation Image';
}

1;
