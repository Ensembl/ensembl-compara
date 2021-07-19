=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::ImageConfig::snpview;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

sub init_cacheable {
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    sortable_tracks => 'drag',  # allow the user to reorder tracks
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
    [ 'variation_legend', '', 'variation_legend', { display => 'normal', strand => 'r', name => 'Variant Legend', caption => 'Variant Legend' }],
    [ 'structural_variation_legend', '', 'structural_variation_legend', { display => 'normal', strand => 'r', name => 'Structural Variant Legend', caption => 'Structural Variant Legend' }],
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
    [qw(gene_legend seg_features reg_feats_core reg_feats_non_core functional_dna_methylation)],
    { display => 'off', menu => 'no' }
  );

  $self->modify_configs(
    [ 'variation_feature_variation', 'variation_set_Phenotype-associated variations', 'regbuild', 'functional_other_regulatory_regions' ],
    { display => 'normal' }
  );

  # setting CRISPR track to structure
  $self->modify_configs(
    [ 'crispr_WGE_CRISPR_sites'],
    { display => 'as_transcript_nolabel' }
  );

  # structural variations
  $self->modify_configs(
    ['variation_feature_structural_larger'],
    { display => 'compact' }
  );
  $self->modify_configs(
    ['variation_feature_structural_smaller'],
    { display => 'gene_nolabel', depth => 100 }
  );

  # Somatic structural variations
  $self->modify_configs(
    [ 'somatic_sv_feature' ],
    { display => 'gene_nolabel', depth => 50 }
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
