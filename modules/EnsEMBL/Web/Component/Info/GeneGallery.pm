=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Info::GeneGallery;

## 

use strict;

use base qw(EnsEMBL::Web::Component::Info::Gallery);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $hub  = $self->hub;

  my $layout = [
                {
                    'title' => 'Sequence &amp; Structure',
                    'pages' => ['Scrolling Browser', 'Region in Detail', 'Immediate Neighbourhood', 'Summary Information', 'Splice Variants', 'Gene Sequence', 'Secondary Structure', 'Supporting Evidence'],
                    'icon'  => 'dna.png',
                  },
                {
                  'title' => 'Function &amp; Regulation',
                  'pages' => ['Table of Ontology Terms', 'Gene Regulation Image', 'Gene Regulation Table', 'Gene Expression'],
                  'icon'  => 'regulation.png',
                },
                  {
                    'title' => 'Transcripts & Proteins',
                    'pages' => ['Transcript Image', 'Transcript Table', 'Transcript Comparison', 'Exons', 'Protein Summary', 'cDNA Sequence', 'Protein Sequence', 'Variation Protein'],
                    'icon'  => 'protein.png',
                  },
                {
                    'title' => 'Comparative Genomics',
                    'pages' => ['Gene Tree', 'Gene Tree Alignments', 'Gene Gain/Loss Tree', 'Summary of Orthologues', 'Table of Orthologues', 'Summary of Paralogues', 'Table of Paralogues', 'Aligned Sequence', 'Region Comparison'],
                    'icon'  => 'compara.png',
                },
                  {
                    'title' => 'Variants',
                    'pages' => ['Variant Table', 'Variant Image', 'Structural Variants'],
                    'icon'  => '',
                  },
                ];

  return $self->format_gallery('Gene', $layout, $self->_get_pages);
}

sub _get_pages {
  ## Define these in a separate method to make content method cleaner
  my $self = shift;
  my $hub = $self->hub;
  my $g = $hub->param('g');

  my $builder   = EnsEMBL::Web::Builder->new($hub);
  my $factory   = $builder->create_factory('Gene');
  my $object    = $factory->object;

  if (!$object) {
    return $self->warning_panel('Invalid identifier', 'Sorry, that identifier could not be found. Please try again.');
  }
  else {

    my $r = $hub->param('r');
    unless ($r) {
      $r = sprintf '%s:%s-%s', $object->slice->seq_region_name, $object->start, $object->end;
    }

    my $avail = $hub->get_query('Availability::Gene')->go($object,{
                          species => $hub->species,
                          type    => $object->get_db,
                          gene    => $object->Obj,
                        })->[0];
    my $not_rna = !$avail->{'has_2ndary'};
    my $no_transcripts = !$avail->{'has_transcripts'};

    return {
            'Scrolling Browser' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'View',
                                                  'r'      => $r,
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'location_genoverse',
                                  'caption'   => 'View the position of this gene in our fully scrollable genome browser',
                                },
            'Region in Detail' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'View',
                                                  'r'      => $r,
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'location_view',
                                  'caption'   => 'Zoom in on your gene of interest',
                                },

            'Immediate Neighbourhood' => {
                                  'link_to'   => {'type'    => 'Gene',
                                                  'action'  => 'Summary',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_summary_image',
                                  'caption'   => 'View this gene in its genomic location',
                                },
            'Aligned Sequence' => {
                                  'link_to'   => {'type'      => 'Location',
                                                  'action'    => 'Compara_Alignments',
                                                  'r'      => $r,
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'location_align',
                                  'caption'   => 'View the region underlying your gene aligned to that of one or more other species',
                                },
            'Region Comparison' => {
                                  'link_to'   => {'type'      => 'Location',
                                                  'action'    => 'Multi',
                                                  'r'      => $r,
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'location_compare',
                                  'caption'   => 'View your gene compared to its homologue in another species',
                                },
            'Summary Information' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Summary',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_summary',
                                  'caption'   => 'General information about this gene, e.g. identifiers and synonyms',
                                },
            'Splice Variants' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Splice',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_splice',
                                  'caption'   => '',
                                },
            'Gene Sequence' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Sequence',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_sequence',
                                  'caption'   => 'DNA sequence of this gene, optionally with variants marked',
                                },
            'Secondary Structure' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'SecondaryStructure',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_secondary',
                                  'caption'   => '',
                                  'disabled'  => $not_rna,
                                  'message'   => 'Only available for RNA genes'
                                },
            'Gene Tree' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Compara_Tree',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_tree',
                                  'caption'   => 'Tree showing homologues of this gene across many species',
                                },
            'Gene Tree Alignments' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Compara_Tree',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_tree_align',
                                  'caption'   => "Alignments of this gene's homologues across many species",
                                },
            'Gene Gain/Loss Tree' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => '',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_cafe_tree',
                                  'caption'   => 'Interactive tree of loss and gain events in a family of genes',
                                },
            'Summary of Orthologues' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Compara_Ortholog',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_ortho_summary',
                                  'caption'   => 'Table showing numbers of different types of orthologue (1-to-1, 1-to-many, etc) in various taxonomic groups',
                                },
            'Table of Orthologues' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Compara_Ortholog',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_ortho_table',
                                  'caption'   => 'Table of orthologues in other species, with links to gene tree, alignments, etc.',
                                },
            'Table of Paralogues' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Compara_Paralog',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_para_table',
                                  'caption'   => 'Table of within-species paralogues, with links to alignments of cDNAs and proteins',
                                },
            'Table of Ontology Terms' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Ontologies',
                                                  'function'  => 'biological_process',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_ontology',
                                  'caption'   => 'Table of ontology terms linked to this gene',
                                },
            'Supporting Evidence' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Evidence',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_support',
                                  'caption'   => "Table of evidence for this gene's transcripts, from protein, EST and cDNA sources",
                                },
            'Gene Expression' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'ExpressionAtlas',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_gxa',
                                  'caption'   => 'Interactive gene expression heatmap',
                                },
            'Gene Regulation Image' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Regulation',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_reg_image',
                                  'caption'   => 'Gene shown in context of regulatory features',
                                },
            'Gene Regulation Table' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Regulation',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_reg_table',
                                  'caption'   => 'Table of regulatory features associated with this gene',
                                },
            };
  }

}

1;
