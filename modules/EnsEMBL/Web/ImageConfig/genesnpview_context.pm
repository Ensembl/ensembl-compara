package EnsEMBL::Web::ImageConfig::genesnpview_context;
use strict;
use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_; 

  $self->set_parameters({
    'title'         => 'Context slice',
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
    'sequence'        => 'Sequence',
    'transcript'      => 'Genes',
    'variation'       => 'Variations', 
    'other'           => 'Other'
  );
  

  $self->add_tracks( 'sequence',
    [ 'contig',    'Contigs',              'stranded_contig', { 'display' => 'normal',  'strand' => 'r'  } ],
  );


  $self->load_tracks();

  $self->add_tracks( 'other',
    [ 'geneexon_bgtrack', '',     'geneexon_bgtrack',  { 'display' => 'normal',  'src' => 'all', 'colours' => 'bisque', 'tag' => 0,'strand' => 'b', 'menu' => 'no'         } ],
    [ 'draggable',        '',     'draggable',         { 'display' => 'normal',  'strand' => 'b', 'menu' => 'no'         } ],
    [ 'snp_join',         '',     'snp_join',          { 'display' => 'on',  'strand' => 'r', 'colours' => $self->species_defs->colour('variation'), 'tag' => 0, 'menu' => 'no'         } ],
    [ 'spacer',           '',     'spacer',            { 'display' => 'normal',  'strand' => 'r', 'menu' => 'no'         } ],
    [ 'ruler',            '',     'ruler',             { 'display' => 'normal',  'strand' => 'f', 'name' => 'Ruler'      } ],
    [ 'scalebar',         '',     'scalebar',          { 'display' => 'normal',  'height' => 50, 'strand' => 'f', 'name' => 'Scale bar'  } ],
  );


  $self->modify_configs(
    [qw(variation_feature_variation)],
    {qw(display normal), 'caption' => 'Variations'}
  );


}
1;
