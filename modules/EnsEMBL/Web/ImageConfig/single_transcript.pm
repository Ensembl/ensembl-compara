# $Id$

package EnsEMBL::Web::ImageConfig::single_transcript;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;

  $self->set_parameters({
    show_labels => 'no'
  });
  
  $self->create_menus('transcript', 'prediction', 'other');

  $self->add_tracks('other',
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'r', name => 'Ruler' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no'    }],
  );

  $self->load_tracks;

  $self->modify_configs(
    [ 'transcript', 'prediction' ],
    { display => 'off', height => 32, non_coding_scale => 0.5 }
  );
  
  $self->storable = 0;
}

1;

