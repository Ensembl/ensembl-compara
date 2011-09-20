# $Id$

package EnsEMBL::Web::ImageConfig::chromosome;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->create_menus('decorations');
  
  $self->add_tracks('decorations', 
    [ 'ideogram', 'Ideogram', 'ideogram',  { display => 'normal', strand => 'r', colourset => 'ideogram' }],
  );
  
  $self->load_tracks;
  
  $self->add_tracks('decorations',
    [ 'draggable', '', 'draggable', { display => 'normal' }]
  );
  
  $self->modify_configs(
    [ 'decorations' ],
    { short_labels => 1 }
  );
  
  $self->storable = 0;
}

1;
