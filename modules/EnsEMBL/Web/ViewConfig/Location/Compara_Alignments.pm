# $Id$

package EnsEMBL::Web::ViewConfig::Location::Compara_Alignments;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Compara_Alignments);

sub init { 
  my $self = shift;
  
  $self->SUPER::init;
  
  $self->{'no_flanking'}   = 1;
  $self->{'strand_option'} = 1;
  
  $self->_set_defaults(qw(
    flank5_display 0 
    flank3_display 0
    panel_top      yes
    strand         1
  ));
  
  if ($self->hub->function eq 'Image') {
    $self->add_image_configs({qw(
      contigviewtop        nodas
      alignsliceviewbottom nodas
    )});
    
    $self->default_config = 'alignsliceviewbottom';
    $self->{'species_only'} = 1;
  }
}

sub form {
  my $self = shift;
  
  $self->add_form_element({ type => 'YesNo', name => 'panel_top', select => 'select', label => 'Show overview panel' }) if $self->hub->function eq 'Image';
  $self->SUPER::form;
}

1;
