# $Id$

package EnsEMBL::Web::ViewConfig::Location::ViewTop;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    show_top_panel => 'yes',
    flanking       => 0,
  });
  
  $self->add_image_config('contigviewtop', 'nodas');
  $self->title = 'Overview Image';
}

sub form {
  my $self = shift;
  
  $self->add_form_element({
    type     => 'NonNegInt', 
    required => 'yes',
    label    => 'Flanking region',
    name     => 'flanking',
    shortnote => sprintf('<div>Ignored if 0 or region is larger than %sMb</div>', $self->hub->species_defs->ENSEMBL_GENOME_SIZE || 1),
   });
   
  $self->add_form_element({ type => 'YesNo', name => 'show_top_panel', select => 'select', label => 'Show panel' });
}

1;