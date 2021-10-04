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
  my $variation_db = $hub->species_defs->databases->{'DATABASE_VARIATION'};

  my $layout = [
                {
                    'title' => 'Sequence &amp; Structure',
                    'pages' => ['Scrolling Browser', 'Region in Detail', 'Immediate Neighbourhood', 'Summary Information', 'Splice Variants', 'Gene Sequence', 'Secondary Structure', 'Supporting Evidence', 'Gene History', 'Gene Identifiers', 'Gene Alleles'],
                    'icon'  => 'dna.png',
                  },
                {
                  'title' => 'Expression &amp; Regulation',
                  'pages' => ['Table of Ontology Terms', 'Gene Regulation Image', 'Gene Regulation Table', 'Gene Expression'],
                  'icon'  => 'regulation.png',
                },
                  {
                    'title' => 'Transcripts & Proteins',
                    'pages' => ['Transcript Table', 'Transcript Summary', 'Transcript Comparison', 'Transcript Image', 'Exon Sequence', 'Protein Summary', 'Transcript cDNA', 'Transcript History', 'Protein Sequence', 'Domains and Features', 'Protein Family Alignments', 'Transcript Identifiers', 'Oligo Probes', 'Protein Variants', 'Protein History'],
                    'icon'  => 'protein.png',
                  },
                {
                    'title' => 'Comparative Genomics',
                    'pages' => ['Gene Tree', 'Gene Tree Alignments', 'Gene Gain/Loss Tree', 'Summary of Orthologues', 'Table of Orthologues', 'Summary of Paralogues', 'Table of Paralogues', 'Protein Family Alignments', 'Gene Family', 'Alignment Image', 'Region Comparison'],
                    'icon'  => 'compara.png',
                },
                  {
                    'title' => 'Variants',
                    'pages' => ['Variant Image', 'Variant Table', 'Structural Variant Image', 'Structural Variant Table', 'Transcript Variant Image', 'Transcript Variant Table', 'Transcript Haplotypes', 'Protein Variants', 'Population Comparison Table', 'Population Comparison Image'],
                    'icon'  => 'variation.png',
                    'disabled' => !$variation_db,
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
    my $not_strain      = $hub->is_strain ? 0 : 1;
    my $has_gxa         = $object->gxa_check;
    my $has_rna         = ($avail->{'has_2ndary'} && $avail->{'can_r2r'}); 
    my $has_tree        = ($avail->{'has_species_tree'} && $not_strain);
    my $has_orthologs   = ($avail->{'has_orthologs'} && $not_strain);
    my $has_paralogs    = ($avail->{'has_paralogs'} && $not_strain);
    my $has_regulation  = !!$hub->species_defs->databases->{'DATABASE_FUNCGEN'};
    my $variation_db    = $hub->species_defs->databases->{'DATABASE_VARIATION'};
    my $has_populations = $variation_db->{'#STRAINS'} if $variation_db ? 1 : 0;
    my $opt_variants    = $variation_db ? ', with optional variant annotation' : '';

    my ($sole_trans, $multi_trans, $multi_prot, $proteins);
    my $transcripts = $object->Obj->get_all_Transcripts || [];

    if (scalar @$transcripts > 1) {
      $multi_trans = {
                      'type'    => 'Transcript',
                      'param'   => 't',
                      'values'  => [{'value' => '', 'caption' => '-- Select transcript --'}],
                      };
    }

    foreach my $t (map { $_->[2] } sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } map { [ $_->external_name, $_->stable_id, $_ ] } @$transcripts) {
      if ($avail->{'multiple_transcripts'}) {
        my $name = sprintf '%s (%s)', $t->external_name || $t->{'stable_id'}, $t->biotype;
        push @{$multi_trans->{'values'}}, {'value' => $t->stable_id, 'caption' => $name};
      }
      else {
        $sole_trans = $t->stable_id;
      }
      $proteins->{$t->stable_id} = $t->translation if $t->translation;
    }
    
    my $prot_count = scalar keys %$proteins;
    if ($prot_count > 1) {
      $multi_prot = {
                      'type'    => 'Protein',
                      'param'   => 'p',
                      'values'  => [{'value' => '', 'caption' => '-- Select protein --'}],
                      };
      foreach my $id (sort {$proteins->{$b}->length <=> $proteins->{$a}->length} keys %$proteins) { 
        my $p     = $proteins->{$id};
        my $text  = sprintf '%s (%s aa)', $p->stable_id, $p->length;
        push @{$multi_prot->{'values'}}, {'value' => $id, 'caption' => $text};
      }
    }

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
            'Alignment Image' => {
                                  'link_to'   => {'type'      => 'Location',
                                                  'action'    => 'Compara_Alignments',
                                                  'function'  => 'Image',
                                                  'r'      => $r,
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'location_align',
                                  'caption'   => 'View the region surrounding your gene aligned to that of one or more other species',
                                  'disabled'  => !$avail->{'has_alignments'},
                                },
            'Region Comparison' => {
                                  'link_to'   => {'type'      => 'Location',
                                                  'action'    => 'Multi',
                                                  'r'      => $r,
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'location_compare',
                                  'caption'   => ' View your gene compared to its orthologue in a species of your choice',
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
                                  'caption'   => 'View the alternate transcripts of this gene',
                                },
            'Gene Alleles' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Alleles',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_alleles',
                                  'caption'   => 'Table of genes that have been annotated on haplotypes and patches as well as on the reference assembly',
                                  'disabled'  => !$avail->{'has_alt_alleles'},
                                },
            'Gene Sequence' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Sequence',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_sequence',
                                  'caption'   => 'DNA sequence of this gene'.$opt_variants, 
                                },
            'Secondary Structure' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'SecondaryStructure',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_secondary',
                                  'caption'   => 'Secondary structure of the RNA product of this gene',
                                  'disabled'  => !$has_rna,
                                  'message'   => 'Only available for RNA genes'
                                },
            'Gene Tree' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Compara_Tree',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_tree',
                                  'caption'   => 'Tree showing homologues of this gene across multiple species',
                                  'disabled'  => !$has_tree,
                                },
            'Gene Tree Alignments' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Compara_Tree',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_tree_align',
                                  'caption'   => "Alignments of this gene's homologues across multiple species",
                                  'disabled'  => !$has_tree,
                                },
            'Gene Gain/Loss Tree' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => '',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_cafe_tree',
                                  'caption'   => 'Interactive tree of loss and gain events in a family of genes',
                                  'disabled'  => !$has_tree,
                                },
            'Summary of Orthologues' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Compara_Ortholog',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_ortho_summary',
                                  'caption'   => 'Table showing numbers of different types of orthologue (1-to-1, 1-to-many, etc) in various taxonomic groups',
                                  'disabled'  => !$has_orthologs,
                                  'message'   => 'It has no orthologues',
                                },
            'Table of Orthologues' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Compara_Ortholog',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_ortho_table',
                                  'caption'   => 'Table of orthologues in other species, with links to gene tree, alignments, etc.',
                                  'disabled'  => !$has_orthologs,
                                  'message'   => 'It has no orthologues',
                                },
            'Table of Paralogues' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Compara_Paralog',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_para_table',
                                  'caption'   => 'Table of within-species paralogues, with links to alignments of cDNAs and proteins',
                                  'disabled'  => !$has_paralogs,
                                  'message'   => 'It has no paralogues',
                                },
            'Protein Family Alignments' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Family',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'protein_family',
                                  'caption'   => "Alignments of protein sequence within a protein family (go to the Protein Family page and click on the 'Wasabi viewer' link)",
                                  'disabled'  => !$prot_count,
                                },
            'Gene Family' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Family',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_family',
                                  'caption'   => 'Locations of all genes in a protein family',
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
                                  'caption'   => "Table of evidence for the annotation of this gene's transcripts, from protein, EST and cDNA sources",
                                },
            'Gene History' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Idhistory',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_history',
                                  'caption'   => "History of a gene's stable ID",
                                  'disabled'  => !$avail->{'history'},
                                },
            'Gene Expression' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'ExpressionAtlas',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_gxa',
                                  'caption'   => 'Interactive heatmap indicating tissue-specific expression patterns of this gene',
                                  'disabled'  => !$has_gxa,
                                },
            'Gene Regulation Image' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Regulation',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_reg_image',
                                  'caption'   => 'Gene shown in context of regulatory features',
                                  'disabled'  => !$avail->{'regulation'},
                                  'message'   => 'This species has no regulatory build',
                                },
            'Gene Regulation Table' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Regulation',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_reg_table',
                                  'caption'   => 'Table of regulatory features associated with this gene',
                                  'disabled'  => !$avail->{'regulation'},
                                  'message'   => 'This species has no regulatory build',
                                },
            'Transcript Comparison' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'TranscriptComparison',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_transcomp',
                                  'caption'   => 'Compare the sequence of two or more transcripts of a gene'.$opt_variants,
                                  'disabled'  => !$multi_trans,
                                  'message'   => 'It has only one transcript',
                                },
            'Gene Identifiers' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Matches',
                                                  'g'      => $g,
                                                 },
                                  'img'       => 'gene_xref',
                                  'caption'   => 'Links to supporting / corresponding records in external databases',
                                },
            'Transcript Summary' => {
                                  'link_to'   => {'type'      => 'Transcript',
                                                  'action'    => 'Summary',
                                                  't'         => $sole_trans,
                                                 },
                                  'img'       => 'trans_summary',
                                  'caption'   => 'General information about a particular transcript of this gene',
                                  'multi'     => $multi_trans,
                                },
            'Transcript Table' => {
                                  'link_to'   => {'type'      => 'Gene',
                                                  'action'    => 'Summary',
                                                  'g'         => $g,
                                                 },
                                  'img'       => 'trans_table',
                                  'caption'   => "Table of information about all transcripts of this gene (click on the 'Show transcript table' button on any gene or transcript page)",
                                },
            'Exon Sequence' => {
                                  'link_to'   => {'type'      => 'Transcript',
                                                  'action'    => 'Exons',
                                                  't'         => $sole_trans,
                                                 },
                                  'img'       => 'trans_exons',
                                  'caption'   => 'Sequences of individual exons within a transcript'.$opt_variants,
                                  'multi'     => $multi_trans,
                                },
            'Transcript cDNA' => {
                                  'link_to'   => {'type'      => 'Transcript',
                                                  'action'    => 'Sequence_cDNA',
                                                  't'         => $sole_trans,
                                                 },
                                  'img'       => 'trans_cdna',
                                  'caption'   => 'cDNA sequence of an individual transcript'.$opt_variants,
                                  'multi'     => $multi_trans,
                                },
            'Protein Sequence' => {
                                  'link_to'   => {'type'      => 'Transcript',
                                                  'action'    => 'Sequence_Protein',
                                                  't'         => $sole_trans,
                                                 },
                                  'img'       => 'trans_protein_seq',
                                  'caption'   => 'Protein sequence of an individual transcript'.$opt_variants,
                                  'disabled'  => !$prot_count,
                                  'multi'     => $multi_prot,
                                },
            'Protein Summary' => {
                                  'link_to'   => {'type'      => 'Transcript',
                                                  'action'    => 'ProteinSummary',
                                                  't'         => $sole_trans,
                                                 },
                                  'img'       => 'trans_protein',
                                  'caption'   => "Image representing the domains found within proteins encoded by the gene’s transcripts, along with any coincident variants",
                                  'disabled'  => !$prot_count,
                                  'multi'     => $multi_prot,
                                },
            'Domains and Features' => {
                                  'link_to'   => {'type'      => 'Transcript',
                                                  'action'    => 'Domains',
                                                  't'         => $sole_trans,
                                                 },
                                  'img'       => 'prot_domains',
                                  'caption'   => 'Table of protein domains and other structural features',
                                  'multi'     => $multi_prot,
                                },
            'Protein Variants' => {
                                  'link_to'   => {'type'      => 'Transcript',
                                                  'action'    => 'ProtVariation',
                                                  't'         => $sole_trans,
                                                 },
                                  'img'       => 'prot_variants',
                                  'caption'   => 'Table of variants associated with the protein of a particular transcript',
                                  'disabled'  => (!$variation_db || !$prot_count),
                                  'multi'     => $multi_prot,
                                },
            'Transcript Identifiers' => {
                                  'link_to'   => {'type'      => 'Transcript',
                                                  'action'    => 'Similarity',
                                                  't'         => $sole_trans,
                                                 },
                                  'img'       => 'trans_xref',
                                  'caption'   => 'Links to supporting / corresponding records in external databases',
                                  'multi'     => $multi_trans,
                                },
            'Oligo Probes' => {
                                  'link_to'   => {'type'      => 'Transcript',
                                                  'action'    => 'Oligos',
                                                  't'         => $sole_trans,
                                                 },
                                  'img'       => 'trans_oligo',
                                  'caption'   => 'List of oligo probes that map to a transcript of this gene',
                                  'disabled'  => !$has_regulation,
                                  'message'   => 'This species has no regulation database',
                                  'multi'     => $multi_trans,
                                },
            'Transcript History' => {
                                  'link_to'   => {'type'      => 'Transcript',
                                                  'action'    => 'Idhistory',
                                                  't'         => $sole_trans,
                                                 },
                                  'img'       => 'trans_history',
                                  'caption'   => "History of the stable ID for one of this gene's transcripts",
                                  'multi'     => $multi_trans,
                                },
            'Protein History' => {
                                  'link_to'   => {'type'      => 'Transcript',
                                                  'action'    => 'Idhistory/Protein',
                                                  't'         => $sole_trans,
                                                 },
                                  'img'       => 'prot_history',
                                  'caption'   => "History of the stable ID for one of this gene's protein products",
                                  'disabled'  => !$prot_count,
                                  'multi'     => $multi_prot,
                                },
            'Transcript Haplotypes' => {
                                  'link_to'   => {'type'      => 'Transcript',
                                                  'action'    => 'Haplotypes',
                                                  't'         => $sole_trans,
                                                 },
                                  'img'       => 'trans_haplotypes',
                                  'caption'   => 'Frequency of protein or CDS haplotypes across major population groups',
                                  'disabled'  => (!$variation_db || !$prot_count),
                                  'multi'     => $multi_trans,
                                },
          'Transcript Variant Image' => {
                                  'link_to'       => {'type'    => 'Transcript',
                                                      'action'  => 'Variation_Transcript/Image',
                                                      't'       => $sole_trans,
                                                      },
                                  'img'       => 'variation_gene_image',
                                  'caption'   => 'Image showing all variants in an individual transcript',
                                  'disabled'  => !$variation_db,
                                  'multi'     => $multi_trans,
                          },
          'Transcript Variant Table' => {
                                  'link_to'       => {'type'    => 'Transcript',
                                                      'action'  => 'Variation_Transcript/Table',
                                                      't'       => $sole_trans,
                                                      },
                                  'img'       => 'variation_gene_table',
                                  'caption'   => 'Table of all variants in an individual transcript',
                                  'disabled'  => !$variation_db,
                                  'multi'     => $multi_trans,
                          },
          'Variant Image' => {
                                  'link_to'       => {'type'    => 'Gene',
                                                      'action'  => 'Variation_Gene/Image',
                                                      'g'       => $g,
                                                      },
                                  'img'       => 'variation_gene_image',
                                  'caption'   => 'Image showing all variants in this gene',
                                  'disabled'  => !$variation_db,
                          },
          'Variant Table' => {
                                  'link_to'       => {'type'    => 'Gene',
                                                      'action'  => 'Variation_Gene/Table',
                                                      'g'       => $g,
                                                      },
                                  'img'       => 'variation_gene_table',
                                  'caption'   => 'Table of all variants in this gene',
                                  'disabled'  => !$variation_db,
                          },
          'Structural Variant Image' => {
                                  'link_to'       => {'type'    => 'Gene',
                                                      'action'  => 'StructuralVariation_Gene',
                                                      'g'       => $g,
                                                      },
                                  'img'       => 'gene_sv_image',
                                  'caption'   => 'Image showing structural variants in this gene',
                                  'disabled'  => !$avail->{'has_structural_variation'},
                                  'message'   => 'No structural variants for this species',
                          },
          'Structural Variant Table' => {
                                  'link_to'       => {'type'    => 'Gene',
                                                      'action'  => 'StructuralVariation_Gene',
                                                      'g'       => $g,
                                                      },
                                  'img'       => 'gene_sv_table',
                                  'caption'   => 'Table of all structural variants in this gene',
                                  'disabled'  => !$avail->{'has_structural_variation'},
                                  'message'   => 'No structural variants for this species',
                          },
          'Population Comparison Image' => {
                                  'link_to'       => {'type'    => 'Transcript',
                                                      'action'  => 'Population/Image',
                                                      't'       => $sole_trans,
                                                      },
                                  'img'       => 'population_image',
                                  'caption'   => 'Image showing variants across different populations',
                                  'disabled'  => !$has_populations,
                                  'message'   => 'This species has no strain populations',
                                  'multi'     => $multi_trans,
                          },
          'Population Comparison Table' => {
                                  'link_to'       => {'type'    => 'Transcript',
                                                      'action'  => 'Population',
                                                      't'       => $sole_trans,
                                                      },
                                  'img'       => 'population_table',
                                  'caption'   => 'Tables of variants within different populations',
                                  'disabled'  => !$has_populations,
                                  'message'   => 'This species has no strain populations',
                                  'multi'     => $multi_trans,
                          },

            };
  }

}

1;
