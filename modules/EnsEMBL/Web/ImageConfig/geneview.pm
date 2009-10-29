package EnsEMBL::Web::ImageConfig::geneview;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;

  $self->set_parameters({
    title        => 'Transcripts panel',
    show_buttons => 'no',  # do not show +/- buttons
    show_labels  => 'no',  # show track names on left-hand side
    label_width  => 113,   # width of labels on left-hand side
    margin       => 5,     # margin
    spacing      => 2,     # spacing
    bgcolor      => 'background1',
    bgcolour1    => 'background2',
    bgcolour2    => 'background3'
  });

  $self->create_menus(
    transcript => 'Other genes',
    prediction => 'Prediction transcripts',
    other      => 'Decorations'
  );
  
  $self->load_tracks;
  
  $self->add_tracks('other',
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'r', name => 'Ruler', description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );

  $_->set('on' => 'off') for $self->get_node('transcript')->descendants, $self->get_node('prediction')->descendants;
}

1;

