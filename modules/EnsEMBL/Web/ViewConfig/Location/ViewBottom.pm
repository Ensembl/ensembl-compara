# $Id$

package EnsEMBL::Web::ViewConfig::Location::ViewBottom;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Cell_line);

sub init {
  my $self = shift;
  $self->title = 'Region Image';
  $self->add_image_config('contigviewbottom');
  $self->SUPER::init;
}

1;
