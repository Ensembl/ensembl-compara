=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ImageConfig::lrg_summary;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    sortable_tracks => 'drag',  # allow the user to reorder tracks
    opt_lines => 1,  # draw registry lines
    opt_empty_tracks => 1,     # include empty tracks
  });

  $self->create_menus(qw(
    sequence
    transcript
    prediction
    lrg
    variation
    somatic
    functional
    external_data
    user_data
    information
  ));

  $self->get_node('transcript')->set_data('caption', 'Other genes');

  my $gencode_version = $self->hub->species_defs->GENCODE_VERSION ? $self->hub->species_defs->GENCODE_VERSION : '';
  $self->add_track('transcript', 'gencode', "Basic Gene Annotations from $gencode_version", '_gencode', {
    labelcaption => "Genes (Basic set from $gencode_version)",
    display     => 'off',
    description => 'The GENCODE set is the gene set for human and mouse. GENCODE Basic is a subset of representative transcripts (splice variants).',
    sortable    => 1,
    colours     => $self->species_defs->colour('gene'),
    label_key  => '[biotype]',
    logic_names => ['proj_ensembl',  'proj_ncrna', 'proj_havana_ig_gene', 'havana_ig_gene', 'ensembl_havana_ig_gene', 'proj_ensembl_havana_lincrna', 'proj_havana', 'ensembl', 'mt_genbank_import', 'ensembl_havana_lincrna', 'proj_ensembl_havana_ig_gene', 'ncrna', 'assembly_patch_ensembl', 'ensembl_havana_gene', 'ensembl_lincrna', 'proj_ensembl_havana_gene', 'havana'],
    renderers   =>  [
      'off',                     'Off',
      'gene_nolabel',            'No exon structure without labels',
      'gene_label',              'No exon structure with labels',
      'transcript_nolabel',      'Expanded without labels',
      'transcript_label',        'Expanded with labels',
      'collapsed_nolabel',       'Collapsed without labels',
      'collapsed_label',         'Collapsed with labels',
      'transcript_label_coding', 'Coding transcripts only (in coding genes)',
    ],
  }) if($gencode_version);

  $self->add_tracks('information',
    [ 'scalebar',  '', 'lrg_scalebar', { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'draggable', '', 'draggable',    { display => 'normal', strand => 'b', menu => 'no' }],
  );

  $self->load_tracks;

  $self->add_tracks('lrg',
    [ 'lrg_transcript', 'LRG transcripts', '_transcript', {
      display     => 'transcript_label',
      strand      => 'b',
      name        => 'LRG transcripts',
      description => 'Transcripts from the <a class="external" href="http://www.lrg-sequence.org">Locus Reference Genomic sequence</a> project.',
      logic_names => [ 'LRG_import' ],
      logic_name  => 'LRG_import',
      colours     => $self->species_defs->colour('gene'),
      label_key   => '[display_label]',
      colour_key  => '[logic_name]',
      zmenu       => 'LRG',
    }],
    [ 'lrg_band', 'LRG gene', 'lrg_band', {
      display     => 'normal',
      strand      => 'f',
      name        => 'LRG gene',
      description => 'Track showing the underlying LRG gene from the <a class="external" href="http://www.lrg-sequence.org">Locus Reference Genomic sequence</a> project.',
      colours     => $self->species_defs->colour('gene'),
      zmenu       => 'LRG',
    }]
  );

  $self->modify_configs(['transcript'], { strand => 'b'});

  $self->modify_configs(
    [ 'fg_regulatory_features_funcgen', 'transcript', 'prediction', 'variation' ],
    { display => 'off' }
  );

  $self->modify_configs(
    [ 'reg_feats_MultiCell' ],
    { display => 'normal' }
  );

  $self->modify_configs(
    [ 'transcript_otherfeatures_refseq_human_import', 'transcript_core_ensembl' ],
    { display => 'transcript_label' }
  );
}

1;
