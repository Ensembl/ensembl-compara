# $Id$

package EnsEMBL::Web::ViewConfig::Regulation::FeaturesByCellLine;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Cell_line);

sub init {
  my $self = shift;
  
  $self->SUPER::init;
  $self->add_image_config('regulation_view') unless $self->hub->function eq 'Cell_line'; 
}

1;
