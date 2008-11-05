package EnsEMBL::Web::ImageConfig::genesnpview_transcripts_top;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'         => 'Transcripts bottom',
    'show_buttons'  => 'yes',   # show +/- buttons
    'button_width'  => 8,       # width of red "+/-" buttons
    'show_labels'   => 'yes',   # show track names on left-hand side
    'label_width'   => 100,     # width of labels on left-hand side
    'margin'        => 5,       # margin
    'spacing'       => 2,       # spacing
    'opt_halfheight'   => 0,    # glyphs are half-height [ probably removed when this becomes a track config ]
    'opt_empty_tracks' => 0,    # include empty tracks..
  });

  $self->create_menus(
    'other'           => 'Other'
  );

  $self->add_tracks( 'other',
    [ 'geneexon_bgtrack', '',     'geneexon_bgtrack',  { 'display' => 'normal', 'src' => 'all', 'colours' => 'bisque', 'tag' => 1, 'strand' => 'f', 'menu' => 'no'  } ],
    [ 'snp_join',         '',     'snp_join',          { 'display' => 'normal',  'strand' => 'f', 'colours' => $self->species_defs->colour('variation'), 'tag' => 1, 'context' => 50, 'menu' => 'no'         } ],
    [ 'draggable',        '',     'draggable',         { 'display' => 'normal',  'strand' => 'f', 'menu' => 'no'         } ],
  );
}
1;
