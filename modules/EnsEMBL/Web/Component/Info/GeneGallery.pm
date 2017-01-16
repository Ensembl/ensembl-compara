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
                  'title' => 'Location',
                  'pages' => ['Scrolling Browser', 'Region in Detail', 'Immediate Neighbourhood', 'Aligned Sequence', 'Region Comparison'],
                  'icon'  => 'karyotype.png',
                },
                {
                    'title' => 'Genes',
                    'pages' => ['Summary Information', 'Splice Variants', 'Gene Sequence', 'Secondary Structure', 'Gene Tree', 'Gene Gain/Loss Tree', 'Summary of Orthologues', 'Table of Orthologues', 'Summary of Paralogues', 'Table of Paralogues', 'Table of Ontology Terms', 'Supporting Evidence', 'Gene Expression', 'Gene Regulation'],
                    'icon'  => 'dna.png',
                  },
                  {
                    'title' => 'Transcripts',
                    'pages' => ['Transcript Image', 'Transcript Table', 'Transcript Comparison', 'Exons', 'Gene Regulation'],
                    'icon'  => 'transcripts.png',
                  },
                  {
                    'title' => 'Proteins',
                    'pages' => ['Protein Summary', 'cDNA Sequence', 'Protein Sequence', 'Variation Protein'],
                    'icon'  => 'protein.png',
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
                                  'caption'   => 'DNA sequence of this gene',
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
                                  'caption'   => 'Tree showing alignments of this gene across many species',
                                },
            'Gene Gain/Loss Tree' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => '',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_',
                                  'caption'   => '',
                                },
            'Summary of Orthologues' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => '',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_',
                                  'caption'   => '',
                                },
            'Table of Orthologues' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => '',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_',
                                  'caption'   => '',
                                },
            'Summary of Paralogues' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => '',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_',
                                  'caption'   => '',
                                },
            'Table of Paralogues' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => '',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_',
                                  'caption'   => '',
                                },
            'Table of Ontology Term' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => '',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_',
                                  'caption'   => '',
                                },
            'Supporting Evidence' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => '',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_',
                                  'caption'   => '',
                                },
            'Gene Expression' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => '',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_',
                                  'caption'   => '',
                                },
            'Gene Regulation' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => '',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_',
                                  'caption'   => '',
                                },
            };
  }

}

1;
