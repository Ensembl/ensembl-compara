# $Id$

package EnsEMBL::Web::ViewConfig::Location::Summary;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->add_image_config('chromosome', 'nodas');
  $self->title = 'Chromosome Image';
}

1;
