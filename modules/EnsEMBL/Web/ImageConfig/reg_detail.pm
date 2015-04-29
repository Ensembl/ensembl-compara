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

package EnsEMBL::Web::ImageConfig::reg_detail;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    opt_lines => 1,
  });  
  
  $self->create_menus(qw(
    sequence
    transcript
    prediction
    dna_align_rna
    simple
    misc_feature
    functional
    multiple_align
    conservation
    variation
    oligo
    repeat
    other
    information
  ));
  
  $self->add_tracks('other',
    [ 'draggable',                '', 'draggable',                { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'fg_background_regulation', '', 'fg_background_regulation', { display => 'normal', strand => 'b', menu => 'no', tag => 0, colours => 'bisque' }],
    [ 'scalebar',                 '', 'scalebar',                 { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',                    '', 'ruler',                    { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }]
  );
 
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
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs', 'contig', { display => 'normal', strand => 'r' }]
  );
  
  $self->load_tracks({ reg_minimal => 1 });
  $self->load_configured_das;
  $self->image_resize = 1;

  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'collapsed_nolabel' }
  );
  
  $self->modify_configs(
    [ 'alignment_compara_431_constrained' ], 
    { display => 'compact' }
 ); 
 
  $self->modify_configs(
    [ 'regulatory_features', 'functional_other_regulatory_regions' ],
    { display => 'normal' }
  );
  
  $self->modify_configs(
    [ 'regulatory_features_core', 'regulatory_features_non_core' ],
    { display => 'off', menu => 'no' }
  );
  
  $self->modify_configs(
    [ 'gene_legend' ],
    { display => 'off' }
  );

  my @feature_sets = ('cisRED', 'VISTA', 'miRanda', 'NestedMICA', 'REDfly CRM', 'REDfly TFBS');
  
  $self->modify_configs(
    [ map "regulatory_regions_funcgen_$_", @feature_sets ],
    { depth => 25, height => 6 }
  );
}

1;
