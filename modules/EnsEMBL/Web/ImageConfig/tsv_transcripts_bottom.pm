package EnsEMBL::Web::ImageConfig::tsv_transcripts_bottom;
use strict;
use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'             => 'Transcripts bottom',
    'show_buttons'      => 'no',    # show +/- buttons
    'button_width'      => 8,       # width of red "+/-" buttons
    'show_labels'       => 'yes',   # show track names on left-hand side
    'label_width'       => 100,     # width of labels on left-hand side
    'margin'            => 5,       # margin
    'spacing'           => 2,       # spacing
    'opt_halfheight'    => 0,    # glyphs are half-height [ probably removed when this becomes a track config ]
    'opt_empty_tracks'  => 0,    # include empty tracks..
  });

  $self->create_menus(
    'other'           => 'Other'
  );

  $self->add_tracks( 'other',
    [ 'transcriptexon_bgtrack', '',     'geneexon_bgtrack',   { 'display' => 'normal', 'src' => 'all', 'colours' => 'bisque', 'tag' => 1, 'strand' => 'r', 'menu' => 'no'  } ],
    [ 'snp_join',               '',     'snp_join',           { 'display' => 'on',  'strand' => 'r', 'context' =>50, 'tag' => 1, 'colours' => $self->species_defs->colour('variation'), 'menu' => 'no'         } ],
    [ 'ruler',                  '',     'ruler',              { 'display' => 'normal',  'strand' => 'r','notext' => 1, 'name' => 'Ruler' } ],
    [ 'spacer',                 '',     'spacer',             { 'display' => 'normal', 'height' => 50,   'strand' => 'r', 'menu' => 'no'         } ],
  );
}





1;
