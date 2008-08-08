package EnsEMBL::Web::ImageConfig::contigviewbottom;

use strict;
use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->set_title( 'Overview panel' );

  $self->create_menus(
    'sequence'              => 'Sequence',
    'marker'                => 'Markers', ## Also includes QTLs!!
    'transcript'            => 'Genes',
    'prediction_transcript' => 'Ab initio predictions',
    'protein_align_feature' => 'Protein alignments',
    'dna_align_feature_cdna'=> 'cDNA/mRNA alignments',
    'dna_align_feature_est' => 'EST alignments',
    'dna_align_feature_rna' => 'RNA alignments',
    'dna_align_feature_other'=>'Other alignments',
    'oligo_probe'           => 'Oligo probes',
    'ditag_feature'         => 'DiTag/CageTag features',
    'simple_feature'        => 'Simple features',
    'variation_feature'     => 'Variation features',
    'regulatory_feature'    => 'Regullatory features',
    'misc_set'              => 'Misc. features/regions',
    'repeat'                => 'Repeats',
    'alignments'            => 'Comparative alignments',
    'synteny'               => 'Synteny',
    'user_data'             => 'User added data',
    'other'                 => 'Additional features',
    'options'               => 'Options'
  );

## Load all tracks from the database....
  $self->load_tracks();

## Now we have a number of tracks which we have to manually add...
  $self->add_tracks(
    'sequence'    => [qw(contig sequence codonseq codons gap)],
    'decorations' => [qw(gap alternative_assembly assemblyexception chr_bands ruler scalebar draggable legends)],
  );
  $self->set_options({
    'show_gene_labels'    => { 'caption' => 'Show gene labels',    'values' => {qw(1 Yes 0 No)}, 'value' => 1 },
    'show_buttons'        => { 'value' => 1 },
    'show_labels'         => { 'value' => 1 },
    'show_register_lines' => { 'caption' => 'Show register lines', 'values' => {qw(1 Yes 0 No)}, 'value' => 1 }
  });
}

1;
