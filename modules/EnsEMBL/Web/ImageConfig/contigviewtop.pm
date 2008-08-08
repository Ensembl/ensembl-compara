package EnsEMBL::Web::ImageConfig::contigviewtop;

use strict;
use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->set_title( 'Overview panel' );

  $self->create_menus(
    'sequence'    => 'Sequence',
    'marker'      => 'Markers',
    'gene'        => 'Genes',
    'misc_set'    => 'Misc. regions',
    'repeat'      => 'Repeats',
    'synteny'     => 'Synteny',
    'user_data'   => 'User uploaded data',
    'other'       => 'Additional features',
    'options'     => 'Options'
  );

## Load all tracks from the database....
  $self->load_tracks();

## Now we have a number of tracks which we have to manually add...
  $self->add_tracks(
    'sequence'    => [qw(contig)],
    'decorations' => [qw(ruler scalebar chr_bands assemblyexception draggable legends)],
  );
  $self->set_options({
    'show_gene_labels'    => { 'caption' => 'Show gene labels',    'values' => {qw(1 Yes 0 No)}, 'value' => 1 },
    'show_buttons'        => { 'value' => 1 },
    'show_labels'         => { 'value' => 1 },
    'show_register_lines' => { 'caption' => 'Show register lines', 'values' => {qw(1 Yes 0 No)}, 'value' => 1 }
  });
}

1;
