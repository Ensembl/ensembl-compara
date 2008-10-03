package EnsEMBL::Web::ImageConfig::single_transcript;
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
  });

  $self->create_menus(
    'transcript' => 'Genes',
    'prediction' => 'Prediction transcripts',
    'other'      => 'Decorations',
  );

  $self->add_tracks( 'other',
    [ 'ruler',     '', 'ruler',     { 'display' => 'normal',  'strand' => 'r', 'name' => 'Ruler' } ],
    [ 'draggable', '', 'draggable', { 'display' => 'normal',  'strand' => 'b', 'menu' => 'no'    } ],
  );

  $self->load_tracks();

  $self->modify_configs(
    [qw(transcript prediction)],
    {qw(display off height 32 non_coding_scale 0.5)}
  );
}
1;

