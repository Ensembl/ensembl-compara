package EnsEMBL::Web::ImageConfig::generegview;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift; 
  my $fset = $self->cache('feature_sets'); 

  $self->set_parameters({
 
    'title'         => 'Regulation Image',
    'show_buttons'  => 'no',  # do not show +/- buttons
    'show_labels'   => 'yes',  # show track names on left-hand side
    'label_width'   => 113,   # width of labels on left-hand side
    'margin'        => 5,     # margin
    'spacing'       => 2,     # spacing
    'bgcolor'       => 'background1',
    'bgcolour1'     => 'background2',
    'bgcolour2'     => 'background3',

  });

  $self->create_menus(
    'transcript'          => 'Genes',
    'prediction'          => 'Prediction transcripts',
    'functional'          => 'Functional genomics',
    'other'               => 'Decorations',
    'information'         => 'Information'
  );


 
  $self->add_tracks( 'other',
    [ 'ruler',     '',            'ruler',           { 'display' => 'on',  'strand' => 'r', 'name' => 'Ruler'      } ],
    [ 'draggable', '',            'draggable',       { 'display' => 'on',  'strand' => 'b', 'menu' => 'no'         } ],
  );

  $self->load_tracks();

  foreach my $child ( $self->get_node('transcript')->descendants,
                      $self->get_node('prediction')->descendants ) {
    $child->set( 'display' => 'off' );
  }

  $self->modify_configs(
    [qw(regulatory_regions_funcgen_search)],
    {qw(display normal)}
  );
  $self->modify_configs(
    [qw(regulatory_regions_funcgen)],
    {qw(display normal)}
  );
  $self->modify_configs(
    [qw(ctcf_funcgen)],
    {qw(display tiling)}
  );
  $self->modify_configs(
    [qw(ctcf_funcgen_blocks)],
    {qw(display compact)}
  );
  $self->modify_configs(
    [qw(histone_modifications_funcgen)],
    {qw(display tiling)}
  );
  $self->modify_configs(
    [qw(gene_legend)],
    {qw(display off)}
  );


}
1;

