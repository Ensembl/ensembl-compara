package EnsEMBL::Web::ImageConfig::geneview;
use strict;
use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;

  $self->set_parameters({
    'title'         => 'Transcript panel',
    'show_buttons'  => 'no',  # do not show +/- buttons
    'show_labels'   => 'no',  # show track names on left-hand side
    'label_width'   => 113,   # width of labels on left-hand side
    'margin'        => 5,     # margin
    'spacing'       => 2,     # spacing
    'bgcolor'       => 'background1',
    'bgcolour1'     => 'background2',
    'bgcolour2'     => 'background3',

  });

  $self->create_menus(
    'other'      => 'Decorations',
    'transcript' => 'Genes',
    'prediction' => 'Prediction transcripts'
  );

  $self->add_tracks( 'other',
    [ 'scalebar',  '',            'scalebar',        { 'on' => 'on',  'strand' => 'f', 'name' => 'Scale bar'  } ],
    [ 'ruler',     '',            'ruler',           { 'on' => 'on',  'strand' => 'r', 'name' => 'Ruler'      } ],
    [ 'draggable', '',            'draggable',       { 'on' => 'on',  'strand' => 'b', 'menu' => 'no'         } ],
  );

  $self->load_tracks();

  foreach my $child ( $self->get_node('transcript')->descendants ) {
    $child->set( 'on' => 'off' );
  }

}
1;

