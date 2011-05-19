# $Id$

package EnsEMBL::Web::ViewConfig::Transcript::TranslationImage;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  $self->add_image_config('protview');
}

1;
