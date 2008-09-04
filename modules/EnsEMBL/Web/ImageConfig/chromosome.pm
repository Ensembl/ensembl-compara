package EnsEMBL::Web::ImageConfig::chromosome;

use strict;
use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'         => 'Chromosome panel',
    'show_buttons'  => 'no',  # do not show +/- buttons
    'button_width'  => 8,     # width of red "+/-" buttons
    'show_labels'   => 'yes', # show track names on left-hand side
    'label_width'   => 113,   # width of labels on left-hand side
    'margin'        => 5,     # margin
    'spacing'       => 2,     # spacing

## Finally some colours... background image colors;
## and alternating colours for tracks...
    'bgcolor'       => 'background1',
    'bgcolour1'     => 'background2',
    'bgcolour2'     => 'background3',
  });

  $self->create_menus(
    'decorations' => 'Chromosome',
  );

## Load all tracks from the database....
#  $self->load_tracks();

## Now we have a number of tracks which we have to manually add...
  $self->add_tracks( 'decorations', 
    [ 'ideogram',           'Ideogram',            'ideogram', {
      'on' => 'on',
      'strand'=>'r',
      'colourset' => 'ideogram'
    } ],
    [ 'assembly_exception', 'Assembly exceptions', 'assemblyexception', {
      'height'        => 2,
      'on'            => 'on', 
      'strand'        => 'x',
      'label_strand'  => 'r',
      'short_labels'  => 1,
      'colourset'     => 'assembly_exception'
    } ],
    [ 'draggable', '', 'draggable', { 'on' => 'on' } ]
  );

  $self->tree->dump("Chromosome configuration", '([[glyphset]] -> [[caption]])');

}
1;
