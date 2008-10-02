package EnsEMBL::Web::ImageConfig::alignsliceviewtop;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'         => 'Overview panel',
    'show_buttons'  => 'no',  # do not show +/- buttons
    'button_width'  => 8,     # width of red "+/-" buttons
    'show_labels'   => 'yes', # show track names on left-hand side
    'label_width'   => 113,   # width of labels on left-hand side
    'margin'        => 5,     # margin
    'spacing'       => 2,     # spacing

## Now let us set some of the optional parameters....
    'opt_lines'         => 1, # draw registry lines
  });

  $self->create_menus(
    'sequence'    => 'Sequence',
    'gene'        => 'Genes',
    'synteny'     => 'Synteny',
    'other'       => 'Additional features',
    'information' => 'Information',
    'options'     => 'Options'
  );

  $self->add_track( 'sequence',    'contig',    'Contigs',             'stranded_contig', { 'display' => 'normal', 'strand' => 'f' } );

  $self->load_tracks();

  $self->add_tracks( 'other',
    [ 'scalebar',  '', 'scalebar',  { 'display' => 'normal'  }],
  );
}

1;
