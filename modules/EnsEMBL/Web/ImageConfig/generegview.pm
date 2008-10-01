package EnsEMBL::Web::ImageConfig::generegview;
use strict;
use base qw(EnsEMBL::Web::ImageConfig::geneview);

sub init {
  my $self = shift; 
  my $fset = $self->cache('feature_sets'); 

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
    'transcript' => 'Genes',
    'prediction' => 'Prediction transcripts',
    'functional' => 'Functional genomics',
    'other'      => 'Decorations',
  );


 $self->add_tracks( 'functional',
   [ 'fg_regulatory_features',  '',     'fg_regulatory_features',    { 'display' => 'on', 'colourset' => 'fg_regulatory_features', 'strand' => 'r', 'name' => 'Reg. Features'  } ],
   [ 'regulatory_search_regions',      '',     'regulatory_search_regions',        { 'display' => 'on', 'colourset' => 'regulatory_search_regions', 'strand' => 'r', 'name' => 'Reg. Regions'  } ],
   [ 'regulatory_regions',      '',     'regulatory_regions',        { 'display' => 'on', 'colourset' => 'synteny', 'strand' => 'r', 'name' => 'Reg. Regions' , 'depth' => 1.5 } ],
   [ 'ctcf',  '',            'ctcf',        { 'on' => 'on',  'colourset' => 'ctcf', 'strand' => 'r', 'name' => 'CTCF'  } ],
   [ 'fg_regulatory_features_legend',  '',     'fg_regulatory_features_legend',    { 'display' => 'on', 'colourset' => 'fg_regulatory_features', 'strand' => 'r', 'name' => 'Reg. Features Legend'  } ],
 );
 
  $self->add_tracks( 'other',
#    [ 'scalebar',  '',            'scalebar',        { 'on' => 'on',  'strand' => 'r', 'name' => 'Scale bar'  } ],
    [ 'ruler',     '',            'ruler',           { 'display' => 'on',  'strand' => 'r', 'name' => 'Ruler'      } ],
    [ 'draggable', '',            'draggable',       { 'display' => 'on',  'strand' => 'b', 'menu' => 'no'         } ],
  );

  $self->load_tracks();

  foreach my $child ( $self->get_node('transcript')->descendants,
                      $self->get_node('prediction')->descendants ) {
    $child->set( 'display' => 'off' );
  }

}
1;

