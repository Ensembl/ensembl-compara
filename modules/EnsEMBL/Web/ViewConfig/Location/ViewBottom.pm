# $Id$

package EnsEMBL::Web::ViewConfig::Location::ViewBottom;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  $self->title = 'Region Image';
  $self->add_image_config('contigviewbottom');
}

1;
