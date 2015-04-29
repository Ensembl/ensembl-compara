=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ImageConfig::contigviewtop;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    sortable_tracks  => 'drag', # allow the user to reorder tracks on the image
    opt_empty_tracks => 0,      # include empty tracks
    opt_lines        => 1,      # draw registry lines
    min_size         => 1e6 * ($self->hub->species_defs->ENSEMBL_GENOME_SIZE || 1),
  });
  
  $self->create_menus(qw(
    sequence
    marker
    transcript
    misc_feature
    synteny
    variation
    decorations
    information
  ));

  my $gencode_version = $self->hub->species_defs->GENCODE ? $self->hub->species_defs->GENCODE->{'version'} : '';
  $self->add_track('transcript', 'gencode', "Basic Gene Annotations from GENCODE $gencode_version", '_gencode', {
    labelcaption => "Genes (Basic set from GENCODE $gencode_version)",
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
  
  $self->add_track('sequence',    'contig', 'Contigs',     'contig', { display => 'normal', strand => 'f' });
  $self->add_track('information', 'info',   'Information', 'text',   { display => 'normal'                });
  
  $self->load_tracks;
  $self->image_resize = 1;
  
  $self->modify_configs([ 'transcript' ], { render => 'gene_label', strand => 'r' });
  $self->modify_configs([ 'variation',  'variation_legend', 'structural_variation_legend' ], { display => 'off', menu => 'no' });

  $self->add_tracks('decorations',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', menu => 'no'                }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', menu => 'no', strand => 'f' }],
    [ 'draggable', '', 'draggable', { display => 'normal', menu => 'no'                }]
  );
}

1;
