package EnsEMBL::Web::ImageConfig::reg_detail;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    'title'         => 'Feature context',
    'show_buttons'  => 'no',
    'show_labels'   => 'yes',
    'label_width'   => 113,
    'opt_lines'     => 1,
    'margin'        => 5,
    'spacing'       => 2,
  });  

  $self->create_menus(
    'sequence'        => 'Sequence',
    'transcript'      => 'Genes',
    'prediction'      => 'Prediction transcripts',
    'dna_align_rna'   => 'RNA alignments',
    'oligo'           => 'Probe features',
    'simple'          => 'Simple features',
    'misc_feature'    => 'Misc. regions',
    'repeat'          => 'Repeats',
    'functional'      => 'Functional Genomics', 
    'multiple_align'  => 'Multiple alignments',
    'variation'       => 'Variation',
    'other'           => 'Decorations',
    'information'     => 'Information', 
  );

  $self->add_tracks( 'other',
    ['fg_wiggle',   '',           'fg_wiggle',       { 'display' => 'tiling', 'colourset' => 'feature_set', 'strand' => 'r', 'menu' => 'no' } ],
    [ 'scalebar',  '',            'scalebar',        { 'display' => 'normal',  'strand' => 'b', 'name' => 'Scale bar'  } ],
    [ 'fg_background_regulation', '',     'fg_background_regulation', { 'display' => 'normal', 'colours' => 'bisque', 'strand' => 'b', 'menu' => 'no' } ],
    [ 'ruler',     '',            'ruler',           { 'display' => 'normal',  'strand' => 'b', 'name' => 'Ruler'      } ],
  );
  $self->add_tracks( 'sequence',
    [ 'contig',    'Contigs',     'stranded_contig', { 'display' => 'normal',  'strand' => 'r'  } ],
  );

  $self->load_tracks;
  $self->load_configured_das;

  $self->modify_configs(
    [qw(fg_regulatory_features_funcgen_reg_feats)],
    {qw(display normal)}
  );
  $self->modify_configs(
    [qw(transcript_core_ensembl)],
    {qw(display collapsed_nolabel)}
  );
  $self->modify_configs(
    [qw(alignment_compara_431_constrained)], 
    {qw(display compact)}
 ); 

}
1;
