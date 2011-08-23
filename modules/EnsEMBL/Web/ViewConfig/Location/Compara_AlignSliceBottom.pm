# $Id$

package EnsEMBL::Web::ViewConfig::Location::Compara_AlignSliceBottom;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Location::Compara_Alignments);

sub init {
  my $self = shift;
  
  $self->SUPER::init;
  
  $self->add_image_config('alignsliceviewbottom', 'nodas');
  
  $self->title            = 'Alignments Image';
  $self->{'species_only'} = 1;
}

1;
