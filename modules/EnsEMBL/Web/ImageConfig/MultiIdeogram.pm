package EnsEMBL::Web::ImageConfig::MultiIdeogram;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

warn "being called";

  $self->set_parameters({
    'title'         => 'Chromosome panel',
    'show_buttons'  => 'no',  # do not show +/- buttons
    'button_width'  => 8,     # width of red "+/-" buttons
    'show_labels'   => 'yes', # show track names on left-hand side
    'label_width'   => 113,   # width of labels on left-hand side
    'margin'        => 5,     # margin
    'spacing'       => 2,     # spacing
    'image_width'   => 800    ### not here surely
  });

  $self->create_menus(
    'decorations' => 'Chromosome',
  );

## Now we have a number of tracks which we have to manually add...
  $self->add_tracks( 'decorations', 
    [ 'ideogram',           'Ideogram',            'ideogram', {
      'display' => 'normal',
      'strand'=>'r',
      'colourset' => 'ideogram'
    } ]
  );
## Load all tracks from the database....
  $self->load_tracks();

  $self->modify_configs(
    [qw(decorations)],
    {qw(short_labels 1)}
  );

  $self->add_tracks( 'decorations', 
    [ 'draggable', '', 'draggable', { 'display' => 'normal' } ]
  );
}
1;
