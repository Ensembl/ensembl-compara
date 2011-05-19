# $Id$

package EnsEMBL::Web::ViewConfig::LRG::TranscriptsImage;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  $self->add_image_config('lrg_summary');
}

1;
