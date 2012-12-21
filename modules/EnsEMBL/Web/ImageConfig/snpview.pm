# $Id$

package EnsEMBL::Web::ImageConfig::snpview;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;

  $self->set_parameters({
    sortable_tracks => 1,  # allow the user to reorder tracks
    opt_halfheight  => 1,  # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_lines       => 1,  # draw registry lines
  });
  
  $self->create_menus(qw(
    sequence
    transcript
    prediction
    variation
    somatic
    functional
    information
    other
  ));
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs', 'contig', { display => 'normal', strand => 'r' }]
  );

  $self->add_tracks('information',
    [ 'variation_legend', '', 'variation_legend', { display => 'normal', strand => 'r', name => 'Variation Legend', caption => 'Variation legend' }]
  );
  
  $self->add_tracks('other',
    [ 'v_line',   '', 'v_line',   { display => 'normal', strand => 'b', name => 'Vertical mark', description => 'Shows the middle of the feature' }],
    [ 'scalebar', '', 'scalebar', { display => 'normal', strand => 'r', name => 'Scale bar',     description => 'Shows the scalebar' }],
    [ 'ruler',    '', 'ruler',    { display => 'normal', strand => 'b', name => 'Ruler',         description => 'Shows the length of the region being displayed' }],
   );

  $self->load_tracks;

  $self->modify_configs(
    [ 'variation' ],
    { style => 'box', depth => 100000 }
  );
 
  $self->modify_configs(
    [ 'gene_legend', 'regulatory_features_core', 'regulatory_features_non_core', 'functional_dna_methylation' ],
    { display => 'off', menu => 'no' }
  );

  $self->modify_configs(
    [ 'variation_feature_variation', 'variation_set_Phenotype-associated variations', 'regulatory_features', 'functional_other_regulatory_regions' ],
    { display => 'normal' }
  );
  
  
  
  # structural variations
  $self->modify_configs(
    [ 'variation_feature_structural' ],
    { display => 'off', depth => 100 }
  );
  $self->modify_configs(
    ['variation_feature_structural_larger'],
    { display => 'normal', depth => 1 }
  );
  $self->modify_configs(
    ['variation_feature_structural_smaller'],
    { display => 'normal', depth => 100 }
  );
  
  # Somatic structural variations
  $self->modify_configs(
    [ 'somatic_sv_feature' ],
    { display => 'normal', depth => 50 }
  );
  
  $self->modify_configs(
    [ 'somatic_mutation_all' ],
    { display => 'normal', style => 'box', depth => 100000 }
  );
  
  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'transcript_label' }
  );
}

1;
