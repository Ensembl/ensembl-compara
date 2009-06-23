package EnsEMBL::Web::ImageConfig::protview;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'         => 'Protein display',
    'show_buttons'  => 'no',   # show +/- buttons
    'button_width'  => 8,       # width of red "+/-" buttons
    'show_labels'   => 'yes',   # show track names on left-hand side
    'label_width'   => 100,     # width of labels on left-hand side
    'margin'        => 5,       # margin
    'spacing'       => 2,       # spacing
  });

  $self->create_menus(
    'domain'         => 'Protein domains',
    'feature'        => 'Protein features',
    'alignment'      => 'Protein alignments',
    'p_variation'    => 'Variation',
#    'user_data'      => 'User data',
    'p_decorations'    => 'Decorations',
#    'legends'        => 'Legends'
  );
  $self->load_tracks();

  $self->add_tracks( 'p_decorations',
    [ 'variation','Variations','P_variation',{ 'display' => 'normal', 'colourset' => 'protein_feature', 'strand' => 'r', 'depth' => 1e5 } ],
    [ 'scalebar', 'Scale bar', 'P_scalebar', { 'display' => 'normal', 'strand' => 'r' } ],
    [ 'exon_structure',  'Protein',   'P_protein',  { 'display' => 'normal', 'colourset' => 'protein_feature', 'strand' => 'f' } ],
  );
  ## Psnp_legend....  'syn'	  => 'chartreuse2', 'in-del'  => 'skyblue2', 'non-syn' => 'gold',
}
1;
