package EnsEMBL::Web::ImageConfig::tsv_transcript;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'             => 'Transcript slice',
    '_options'          => [qw(pos col known unknown)],
    'show_buttons'      => 'no',    # show +/- buttons 
    'button_width'      => 8,       # width of red "+/-" buttons
    'show_labels'       => 'yes',   # show track names on left-hand side
    'label_width'       => 100,     # width of labels on left-hand side
    'margin'            => 5,       # margin
    'spacing'           => 2,       # spacing
    'opt_halfheight'    => 0,    # glyphs are half-height [ probably removed when this becomes a track config ]
    'opt_empty_tracks'  => 0,    # include empty tracks..
    '_add_labels'       => 1, 
 });


  $self->create_menus(
    'transcript'    => 'Genes',
    'variation'       => 'Variations',
    'prediction'    => 'Prediction transcripts',
    'other'         => 'Decorations',
 );

  $self->load_tracks();

  $self->modify_configs(
    [qw(transcript)],
    {'display' => 'off'}
  );
 $self->add_tracks( 'transcript',
    [ 'snp_join',               '',     'snp_join',               { 'display' => 'on',  'strand' => 'b','tag' => 0, 'colours' => $self->species_defs->colour('variation'), 'menu' => 'no'         } ],
 );
 $self->add_tracks( 'other',
    [ 'transcriptexon_bgtrack', '',     'transcriptexon_bgtrack', { 'display' => 'normal',  'src' => 'all', 'colours' => 'bisque', 'tag' => 0,'strand' => 'b', 'menu' => 'no'         } ],
    [ 'scalebar',               '',     'scalebar',               { 'display' => 'normal', 'strand' => 'f', 'name' => 'Scale bar' } ],
    [ 'ruler',                  '',     'ruler',                  { 'display' => 'normal',  'strand' => 'f','notext' => 1, 'name' => 'Ruler'  } ],
    [ 'spacer',                 '',     'spacer',                 { 'display' => 'normal', 'height' =>20,  'strand' => 'r', 'menu' => 'no'         } ],
  );

  $self->modify_configs(
    [qw(variation_feature_variation)],
    {qw(display normal), 'caption' => 'Variations', 'strand' => 'f'}
  );



}
1;

