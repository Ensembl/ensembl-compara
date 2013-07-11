# $Id$

package EnsEMBL::Web::ImageConfig::chromosome;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    label_width => 130, # width of labels on left-hand side
  });
  
  $self->{'extra_menus'} = { display_options => 1 };
  
  $self->create_menus('decorations');
  
  $self->add_tracks('decorations', 
    [ 'ideogram', 'Ideogram', 'ideogram',  { display => 'normal', menu => 'no', strand => 'r', colourset => 'ideogram' }],
  );
  
  $self->load_tracks;
  
  $self->add_tracks('decorations',
    [ 'draggable', '', 'draggable', { display => 'normal', menu => 'no' }]
  );
  
  $self->get_node('decorations')->set('caption', 'Decorations');
  
  $self->modify_configs(
    [ 'decorations' ],
    { short_labels => 1 }
  );
}

1;
