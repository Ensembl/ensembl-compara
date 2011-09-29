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
  
  $self->set_defaults({
    opt_conservation_scores  => 'off',
    opt_constrained_elements => 'off',
  });
}

sub form {
  my $self = shift;
  
  $self->add_fieldset('Comparative features');
  
  $self->add_form_element({
    type  => 'CheckBox', 
    label => 'Conservation scores for the selected alignment',
    name  => 'opt_conservation_scores',
    value => 'tiling',
  });
  
  $self->add_form_element({
    type  => 'CheckBox', 
    label => 'Constrained elements for the selected alignment',
    name  => 'opt_constrained_elements',
    value => 'compact',
  });
  
  $self->SUPER::form;
}

1;
