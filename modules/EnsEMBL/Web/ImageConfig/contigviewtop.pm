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

  $self->load_tracks();

  $self->add_tracks( 'sequence', qw(contig) );
  $self->add_track(  'marker',   qw(marker) );
  $
  $self->set_track_sets( # Listed in direction - middle -> outside
    'sequence'    => qw(contig),      # assembly contigs...
    'markers'     => qw(marker),      # data from the marker table
    'gene'        => qw(:gene),       # data from the gene table
    'misc_sets'   => qw(:misc_set),   # data from the misc_set table
    'repeats'     => qw(:repeat),     # data from the repeat_feature table
    'synteny'     => qw(:synteny),    # data from the compara synteny tables.
    'user_data'   => qw(:user_data),  # user configured das sources
    'outer_decs'  => qw(ruler scalebar chr_bands assemblyexception draggable),
    'legends'     => qw(:legends)
  );
  $self->set_options({
    'show_gene_labels'    => { 'caption' => 'Show gene labels',    'values' => {qw(yes Yes no No)} },
    'show_register_lines' => { 'caption' => 'Show register lines', 'values' => {qw(yes Yes no No)} }
  });
  $self->show_buttons( 'no' );
  $self->label_width( 113 );
}

1;
