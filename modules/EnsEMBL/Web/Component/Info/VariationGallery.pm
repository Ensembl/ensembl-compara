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

package EnsEMBL::Web::Component::Info::VariationGallery;

## 

use strict;

use base qw(EnsEMBL::Web::Component::Info);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;

  ## Define page layout 
  ## Note: We structure it like this, because for improved findability, pages can appear 
  ## under more than one heading. Configurations for individual views are defined in a
  ## separate method, lower down this module
  my $layout = [
                  {
                    'title' => 'Locations',                      
                    'pages' => ['Region in Detail', 'Genomic Context', 'Flanking Sequence', 'Phylogenetic Context', 'LD Image'],
                    'icon'  => 'karyotype.png',
                  },
                  {
                    'title' => 'Genes',
                    'pages' => ['Gene Sequence', 'Gene Table', 'Gene Image', 'Gene Regulation', 'Citations'],
                    'icon'  => 'dna.png',
                  },
                  {
                    'title' => 'Transcripts',
                    'pages' => ['Transcript Image', 'Transcript Table', 'Transcript Comparison', 'Exons', 'Gene Regulation', 'Citations'],
                    'icon'  => 'transcripts.png',
                  },
                  {
                    'title' => 'Proteins',
                    'pages' => ['Protein Summary', 'cDNA Sequence', 'Protein Sequence', 'Variation Protein', 'Citations'],
                    'icon'  => 'protein.png',
                  },
                  {
                    'title' => 'Phenotypes',
                    'pages' => ['Phenotype Table', 'Gene Phenotype', 'Phenotype Karyotype', 'Phenotype Location Table', 'Citations'],
                    'icon'  => 'var_phenotype_data.png',
                  },
                  {
                    'title' => 'Populations &amp; Individuals',
                    'pages' => ['Population Image', 'Population Table', 'Genotypes Table', 'LD Image', 'LD Table', 'Resequencing', 'Citations'],
                    'icon'  => 'var_sample_information.png',
                  },
                ];

  my $pages = $self->_get_pages;

  if (ref($pages) eq 'HASH') {
    return $self->format_gallery('Variation', $layout, $pages);
  }
  else {
    return $pages; ## error message
  }

}

sub _get_pages {
  ## Define these in a separate method to make content method cleaner
  my $self = shift;
  my $hub = $self->hub;
  my $v = $hub->param('v');

  ## Check availabity of views for this variant
  my ($no_location, $multi_location) = (0, 0);
  my ($no_location, $no_gene, $no_phenotype, $no_protein) = (0, 0, 0, 0);
  my ($multi_location, $multi_gene, $multi_transcript, $multi_protein, $multi_phenotype);

  my $builder   = $hub->{'_builder'};
  my $factory   = $builder->create_factory('Variation');
  my $object    = $factory->object;

  if (!$object) {
    return $self->warning_panel('Invalid identifier', 'Sorry, that identifier could not be found. Please try again.');
  }
  else {
    ## Location checking
    my %mappings = %{$object->variation_feature_mapping};
    if (scalar keys %mappings == 0) {
      $no_location = 1;
      $no_gene = 1;
    }
    elsif (scalar keys %mappings > 1) {
      $multi_location = {
                          'type'    => 'Location',
                          'param'   => 'r',
                          'values'  => [{'value' => '', 'caption' => '-- Select coordinates --'}],
                          };
      foreach (sort { $mappings{$a}{'Chr'} cmp $mappings{$b}{'Chr'} || $mappings{$a}{'start'} <=> $mappings{$b}{'start'}} keys %mappings) {
        my $coords = sprintf('%s:%s-%s', $mappings{$_}{'Chr'}, $mappings{$_}{'start'}, $mappings{$_}{'end'});
        push @{$multi_location->{'values'}}, {'value' => $coords, 'caption' => $coords};
      }
    }

    ## Gene and transcript checking
    my ($g, $t, %genes, %transcripts, %translations);
    my $gene_adaptor  = $hub->get_adaptor('get_GeneAdaptor');
    my $trans_adaptor = $hub->get_adaptor('get_TranscriptAdaptor');
    foreach my $varif_id (grep $_ eq $hub->param('vf'), keys %mappings) {
      foreach my $transcript_data (@{$mappings{$varif_id}{'transcript_vari'}}) {

        my $gene = $gene_adaptor->fetch_by_transcript_stable_id($transcript_data->{'transcriptname'}); 
        if ($gene) {
          $genes{$gene->stable_id} = $self->gene_name($gene);
          my $transcript           = $trans_adaptor->fetch_by_stable_id($transcript_data->{'transcriptname'});
          if ($transcript) {
            my $biotype = $transcript->biotype;
            my $name    = $self->gene_name($transcript);
            $transcripts{$transcript->stable_id} = {
                                                    'name'    => $name,
                                                    'biotype' => $biotype,
                                                    };
            if ($biotype eq 'protein-coding') { 
              $translations{$transcript->stable_id} = $name;
            }
          }
        }
      }
    }
    
    if (scalar keys %transcripts) {
      if (scalar keys %transcripts > 1) {
        my @strings;
        while (my($id, $info) = each (%transcripts)) {
          push @strings, $id.'_'.$info->{'biotype'};
        }
        my $params = {
                      'type'        => 'ZMenu', 
                      'action'      => 'Gallery_TranscriptVariant', 
                      'transcripts' => join(':', @strings),
                      'v'           => $v,
                      };
        $multi_transcript = {
                            'type'  => 'Transcript',
                            'zmenu' => $params,
                            };
      }
      else {
        my @ids = keys %transcripts;
        $t = $ids[0];
      }
    } 

    if (scalar keys %translations) {
      if (scalar keys %translations > 1) {
        $multi_protein = {
                          'type'    => 'Transcript',
                          'param'   => 't',
                            'values'  => [{'value' => '', 'caption' => '-- Select transcript --'}],
                          };
        foreach (sort {$translations{$a} cmp $translations{$b}} keys %translations) {
          push @{$multi_protein->{'values'}}, {'value' => $_, 'caption' => $translations{$_}};
        }
      }
    }
    else {
      $no_protein = 1;
    }

    if (scalar keys %genes) {
      if (scalar keys %genes > 1) {
        $multi_gene = {
                          'type'    => 'Gene',
                          'param'   => 'g',
                          'values'  => [{'value' => '', 'caption' => '-- Select gene --'}],
                          };
        foreach (sort {$genes{$a} cmp $genes{$b}} keys %genes) {
          push @{$multi_gene->{'values'}}, {'value' => $_, 'caption' => $genes{$_}};
        }
      }
      else {
        my @ids = keys %genes;
        $g = $ids[0];
      }
    }

    ## Phenotype checking
    my $pfs = $object->get_ega_links;
    if (scalar($pfs)) {
      if (scalar($pfs) > 1) {
        $multi_phenotype = {
                          'type'    => 'Phenotype',
                          'param'   => 'ph',
                          'values'  => [{'value' => '', 'caption' => '-- Select phenotype --'}],
                          };
        foreach (@$pfs) {
          my $id = $_->{'_phenotype_id'};
          my $name = $_->phenotype->description;
          push @{$multi_phenotype->{'values'}}, {'value' => $id, 'caption' => $name};
        }
      }
    }
    else {
      $no_phenotype = 1;
    }


    return {'Region in Detail' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'View',
                                                  'v'      => $v,
                                                 },
                                  'img'       => 'variation_location',
                                  'caption'   => 'Region where your variant is located',
                                  'multi'     => $multi_location,  
                                  'disabled'  => $no_location,  
                                },
          'Genomic Context' => {
                                  'link_to'   => {'type'    => 'Variation',
                                                  'action' => 'Context',
                                                  'v'      => $v,
                                                 },
                                  'img'       => 'variation_genomic',
                                  'caption'   => 'Genomic context of your variant',
                                },
          'Flanking Sequence' => {
                                  'link_to'   => {'type'    => 'Variation',
                                                  'action'  => 'Sequence',
                                                  'v'      => $v,
                                                  },
                                  'img'     => 'variation_sequence',
                                  'caption' => 'Flanking sequence for your variant',
                                  },
          'Phylogenetic Context' => {
                                  'link_to'     => {'type'    => 'Variation',
                                                    'action'  => 'Compara_Alignments',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_phylogenetic',
                                  'caption' => 'Phylogenetic context of your variant',
                                  },
          'Gene Sequence' => {
                                  'link_to'       => {'type'  => 'Gene',
                                                      'action'  => 'Sequence',
                                                      'v'       => $v,
                                                      'g'       => $g,
                                                      'snp_display' => 'yes',
                                                      },
                                  'img'       => 'variation_gene_seq',
                                  'caption'   => 'Sequence of the gene overlapping your variant',
                                  'multi'     => $multi_gene,  
                                  'disabled'  => $no_gene,  
                            },
          'Gene Image' => {
                                  'link_to'       => {'type'    => 'Gene',
                                                      'action'  => 'Variation_Gene/Image',
                                                      'v'       => $v,
                                                      'g'       => $g,
                                                      },
                                  'img'       => 'variation_gene_image',
                                  'caption'   => 'Image showing all variants in the same gene as this one',
                                  'multi'     => $multi_gene,  
                                  'disabled'  => $no_gene,  
                          },
          'Gene Table' => {
                                  'link_to'       => {'type'    => 'Gene',
                                                      'action'  => 'Variation_Gene/Table',
                                                      'v'      => $v,
                                                      'g'       => $g,
                                                      },
                                  'img'       => 'variation_gene_table',
                                  'caption'   => 'Table of all variants in the same gene as this one',
                                  'multi'     => $multi_gene,  
                                  'disabled'  => $no_gene,  
                          },
          'Gene Regulation' => {
                                  'link_to'     => {'type'    => 'Variation',
                                                    'action'  => 'Mappings',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_mappings',
                                  'caption' => 'Genes and regulatory features around your variant',
                                },
          'Citations' => {
                                  'link_to'     => {'type'    => 'Variation',
                                                    'action'  => 'Citations',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_citations',
                                  'caption' => 'Papers citing your variant',
                                },
          'Transcript Image' => {
                                  'link_to'     => {'type'    => 'Transcript',
                                                    'action'  => 'Variation_Transcript/Image',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_trans_image',
                                  'caption' => 'Image showing all variants within the same transcript as this one',
                                  'multi'     => $multi_transcript,  
                                  'disabled'  => $no_gene,  
                                },
          'Transcript Table' => {
                                  'link_to'     => {'type'    => 'Transcript',
                                                    'action'  => 'Variation_Transcript/Table',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_trans_table',
                                  'caption' => 'Table of variants within the same transcript as this one',
                                  'multi'     => $multi_transcript,  
                                  'disabled'  => $no_gene,  
                                },
          'Transcript Comparison' => {
                                  'link_to'     => {'type'    => 'Gene',
                                                    'action'  => 'TranscriptComparison',
                                                    'v'      => $v,
                                                    'g'       => $g,
                                                    },
                                  'img'     => 'variation_trans_comp',
                                  'caption' => "Comparison of a gene's transcripts, showing variants",
                                  'multi'     => $multi_gene,  
                                  'disabled'  => $no_gene,  
                                },
          'Exons' => {
                                  'link_to'     => {'type'    => 'Transcript',
                                                    'action'  => 'Exons',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_exons',
                                  'caption' => 'Variations within each exon sequence',
                                  'multi'     => $multi_transcript,  
                                  'disabled'  => $no_gene,  
                                },
          'Protein Summary' => {
                                  'link_to'     => {'type'    => 'Transcript',
                                                    'action'  => 'ProteinSummary',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_protein',
                                  'caption' => "Variants on a protein's domains",
                                  'multi'     => $multi_transcript,  
                                  'disabled'  => $no_protein,  
                                },
          'cDNA Sequence' => {
                                  'link_to'     => {'type'    => 'Transcript',
                                                    'action'  => 'Sequence_cDNA',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_cdna_seq',
                                  'caption' => 'Variants on cDNA sequence',
                                  'multi'     => $multi_transcript,  
                                  'disabled'  => $no_gene,  
                                },
          'Protein Sequence' => {
                                  'link_to'     => {'type'    => 'Transcript',
                                                    'action'  => 'Sequence_Protein',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_protein_seq',
                                  'caption' => 'Variants on protein sequence',
                                  'multi'     => $multi_transcript,  
                                  'disabled'  => $no_protein,  
                                },
          'Variation Protein' => {
                                  'link_to'     => {'type'    => 'Transcript',
                                                    'action'  => 'ProtVariations',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_protvars',
                                  'caption' => 'Table of variants for a protein',
                                  'multi'     => $multi_transcript,  
                                  'disabled'  => $no_protein,  
                                },
          'Phenotype Table' => {
                                  'link_to'     => {'type'    => 'Variation',
                                                    'action'  => 'Phenotype',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_phenotype',
                                  'caption' => 'Phenotypes associated with your variant',
                                  'multi'     => $multi_phenotype,  
                                  'disabled'  => $no_phenotype,  
                                },
          'Gene Phenotype' => {
                                  'link_to'     => {'type'    => 'Gene',
                                                    'action'  => 'Phenotype',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_gen_phen',
                                  'caption' => 'Phenotypes associated with a gene which overlaps your variant',
                                  'multi'     => $multi_phenotype,  
                                  'disabled'  => $no_phenotype,  
                                },
          'Phenotype Karyotype' => {
                                  'link_to'     => {'type'    => 'Phenotype',
                                                    'action'  => 'Locations',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_karyotype',
                                  'caption' => 'Locations of all variants associated with the same phenotype as this one',
                                  'multi'     => $multi_phenotype,  
                                  'disabled'  => $no_phenotype,  
                                },
          'Phenotype Location Table' => {
                                  'link_to'     => {'type'    => 'Phenotype',
                                                    'action'  => 'Locations',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_phen_table',
                                  'caption' => 'Table of variants associated with the same phenotype as this one',
                                  'multi'     => $multi_phenotype,  
                                  'disabled'  => $no_phenotype,  
                                },
          'Population Table' => {
                                  'link_to'     => {'type'    => 'Variation',
                                                    'action'  => 'Population',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_pop_table',
                                  'caption' => 'Table of allele frequencies in different populations',
                                },
          'Population Image' => {
                                  'link_to'     => {'type'    => 'Variation',
                                                    'action'  => 'Population',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_pop_piecharts',
                                  'caption' => 'Pie charts of allele frequencies in different populations',
                                },
          'Genotypes Table' => {
                                  'link_to'     => {'type'    => 'Variation',
                                                    'action'  => 'Sample',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_sample',
                                  'caption' => 'Genotypes for samples within a population',
                                },
          'LD Image' => {
                                  'link_to'       => {'type'    => 'Location',
                                                      'action'  => 'LD',
                                                      'v'      => $v,
                                                      },
                                  'img'       => 'variation_ld_image',
                                  'caption'   => 'Linkage disequilibrium plot in a region',
                                  'multi'     => $multi_location,  
                                  'disabled'  => $no_location,  
                                },
          'LD Table' => {
                                  'link_to'     => {'type'    => 'Variation',
                                                    'action'  => 'HighLD',
                                                    'v'      => $v,
                                                    },
                                  'img'     => 'variation_ld_table',
                                  'caption' => 'Linkage disequilibrium with your variant',
                                },
          'Resequencing' => {
                                  'link_to'       => {'type'    => 'Location',
                                                      'action'  => 'SequenceAlignment',
                                                      'v'      => $v,
                                                      },
                                  'img'       => 'variation_resequencing',
                                  'caption'   => 'Variants in resequenced samples',
                                  'multi'     => $multi_location,  
                                  'disabled'  => $no_location,  
                                },
    };
  }
}

1;
