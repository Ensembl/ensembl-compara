# $Id$

package EnsEMBL::Web::ImageConfig::chromosome;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;

  $self->set_parameters({
    title => 'Chromosome panel',
  });
  
  $self->create_menus('decorations');
  
  $self->add_tracks('decorations', 
    [ 'ideogram', 'Ideogram', 'ideogram',  { display => 'normal', strand => 'r', colourset => 'ideogram' }],
    [ 'draggable', '',        'draggable', { display => 'normal' }]
  );
  
  $self->load_tracks;
  
  $self->modify_configs(
    [ 'decorations' ],
    { short_labels => 1 }
  );
  
  $self->storable = 0;
}

1;
