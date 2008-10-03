package EnsEMBL::Web::ImageConfig::genesnpview_transcripts_bottom;
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
    [ 'geneexon_bgtrack', '',     'geneexon_bgtrack',  { 'display' => 'normal', 'src' => 'all', 'colour' => 'bisque', 'tag' => 2, 'strand' => 'r', 'menu' => 'no'         } ],
#    [ 'snp_join',         '',     'snp_join',          { 'display' => 'normal',  'strand' => 'r', 'menu' => 'no'         } ],
    [ 'draggable',        '',     'draggable',         { 'display' => 'normal',  'strand' => 'r', 'menu' => 'no'         } ],
    [ 'ruler',            '',     'ruler',             { 'display' => 'normal',  'strand' => 'r', 'name' => 'Ruler'      } ],
    [ 'spacer',           '',     'spacer',            { 'display' => 'normal', 'height' => 50,   'strand' => 'r', 'menu' => 'no'         } ],
  );
}
1;
