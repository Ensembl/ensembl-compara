# $Id$

package EnsEMBL::Web::ViewConfig::Location::StructuralVariant;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  $self->add_image_config('StructuralVariant');
  $self->title = 'Structural Variation';
}

1;