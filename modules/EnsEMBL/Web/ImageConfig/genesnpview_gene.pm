package EnsEMBL::Web::ImageConfig::genesnpview_gene;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'         => 'Transcript slice',
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
    'sequence'        => 'Sequence',
    'transcript'      => 'Genes',
    'other'           => 'Other'
  );
  $self->load_tracks();

  $self->add_tracks( 'other',
    [ 'geneexon_bgtrack', '',     'geneexon_bgtrack',  { 'display' => 'normal', 'src' => 'all', 'colours' => 'bisque', 'tag' => 1, 'strand' => 'b', 'menu' => 'no'         } ],
    [ 'draggable',        '',     'draggable',         { 'display' => 'normal',  'strand' => 'b', 'menu' => 'no'         } ],
    [ 'snp_join',         '',     'snp_join',          { 'display' => 'on',  'strand' => 'b', 'colours' => $self->species_defs->colour('variation'), 'tag' => 1, 'menu' => 'no'         } ], 
    [ 'variation_legend',           '',     'variation_legend',            { 'display' => 'on', 'strand' => 'r',          } ],
    [ 'spacer',           '',     'spacer',            { 'display' => 'normal', 'height' => 50,   'strand' => 'r', 'menu' => 'no'         } ],
  );


  $self->modify_configs(
    [qw(transcript )],
    {'display'=>'off'}
  );

}

1;
