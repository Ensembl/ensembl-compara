# $Id$

package EnsEMBL::Web::ViewConfig::Gene::TranscriptsImage;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  $self->add_image_config('gene_summary');
}

1;
