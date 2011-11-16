# $Id$

package EnsEMBL::Web::ViewConfig::Location::ChromosomeImage;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {  
  my $self = shift;
  $self->add_image_config('Vmapview', 'nodas');
  $self->title = 'Chromosome Image';
}

1;
