package EnsEMBL::Web::ImageConfig::tsv_sampletranscript;

use warnings;
no warnings 'uninitialized';
use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->set_parameters({
    'title'         => 'Sample Transcript slice', 
    'show_buttons'  => 'no',    # show +/- buttons
    'button_width'  => 8,       # width of red "+/-" buttons
    'show_labels'   => 'yes',   # show track names on left-hand side
    'label_width'   => 100,     # width of labels on left-hand side
    'margin'        => 5,       # margin
    'spacing'       => 2,       # spacing
    'features'      => [],
    'opt_halfheight'   => 0,    # glyphs are half-height [ probably removed when this becomes a track config ]
    'opt_empty_tracks' => 0,    # include empty tracks..
  });

  $self->create_menus(
    'tsv_transcript'  => '',
    'other'           => 'Other'
  );

  $self->load_tracks();

  $self->add_tracks( 'other',
    [ 'coverage_top',       '',     'coverage',               { 'display' => 'on',  'strand' => 'r', 'type' => 'top', 'caption' => 'Resequence coverage', 'menu' => 'no', } ],
    [ 'tsv_variations',     '',     'tsv_variations',         { 'display' => 'normal',  'strand' => 'r', 'colours' => $self->species_defs->colour('variation'), 'menu' => 'no'  } ],
 );


}
1;

