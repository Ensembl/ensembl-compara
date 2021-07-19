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

package EnsEMBL::Web::OldLinks;

### Redirect URLs for both pre-51-style URLs and new/renamed pages in archive links 

use strict;

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(get_redirect get_archive_redirect);

## Mappings for URLs prior to Ensembl release 51 (still used by some incoming links!)
## Shouldn't need updating

our %script_mapping = (
  'blastview'             => 'Tools/Blast',
  'featureview'           => 'Location/Genome',
  'karyoview'             => 'Location/Genome',
  'mapview'               => 'Location/Chromosome',
  'cytoview'              => 'Location/Overview', 
  'contigview'            => 'Location/View',    
  'sequencealignview'     => 'Location/SequenceAlignment', 
  'syntenyview'           => 'Location/Synteny',          
  'markerview'            => 'Location/Marker',          
  'ldview'                => 'Location/LD',             
  'multicontigview'       => 'Location/Multi',         
  'alignsliceview'        => 'Location/Compara_Alignments/Image', 
  'geneview'              => 'Gene/Summary',                
  'genespliceview'        => 'Gene/Splice',                   
  'geneseqview'           => 'Gene/Sequence',                
  'generegulationview'    => 'Gene/Regulation',             
  'geneseqalignview'      => 'Gene/Compara_Alignments',    
  'genetree'              => 'Gene/Compara_Tree',         
  'familyview'            => 'Gene/Family',              
  'genesnpview'           => 'Gene/Variation_Gene',     
  'idhistoryview'         => 'Gene/Idhistory',         
  'transview'             => 'Transcript/Summary',    
  'exonview'              => 'Transcript/Exons',     
  'protview'              => 'Transcript/ProteinSummary',   
  'transcriptsnpview'     => 'Transcript/Population',      
  'domainview'            => 'Transcript/Domains/Genes',  
  'alignview'             => 'Transcript/SupportingEvidence/Alignment',
  'snpview'               => 'Variation/Explore',                    
  'searchview'            => 'Search/Results',            
  'search'                => 'Search/Results',             
  # internal views
  'colourmap'             => 'Server/Colourmap',          
  'status'                => 'Server/Information',       
  'helpview'              => 'Help/Search',             
);


## Add new views here, and for renamed views, create links both ways (for fast lookup)
 
our %archive_mapping = (
                        'Info/Index'                              => { 'initial_release' => 51 },
                        'Info/Error'                              => { 'initial_release' => 51 },
                        'Info/Error_400'                          => { 'initial_release' => 51 },
                        'Info/Error_401'                          => { 'initial_release' => 51 },
                        'Info/Error_403'                          => { 'initial_release' => 51 },
                        'Info/Error_404'                          => { 'initial_release' => 51 },
                        'Info/Error_555'                          => { 'initial_release' => 86 },
                        'Info/Annotation'                         => { 'initial_release' => 51 },
                        'Info/WhatsNew'                           => { 'initial_release' => 51 },
                        'Info/Content'                            => { 'initial_release' => 51 },
                        'Info/Expression'                         => { 'initial_release' => 77 },
                        'Info/LocationGallery'                    => { 'initial_release' => 88 },
                        'Info/GeneGallery'                        => { 'initial_release' => 88 },
                        'Info/VariationGallery'                   => { 'initial_release' => 88 },
                        'Info/CheckGallery'                       => { 'initial_release' => 88 },

                        'Location/Genome'                         => { 'initial_release' => 51 },                         
                        'Location/Chromosome'                     => { 'initial_release' => 51 },                         
                        'Location/Overview'                       => { 'initial_release' => 51 },                         
                        'Location/View'                           => { 'initial_release' => 51 },                         
                        'Location/Synteny'                        => { 'initial_release' => 51 },                         
                        'Location/Variation'                      => { 'initial_release' => 51 },                         
                        'Location/SequenceAlignment'              => { 'initial_release' => 51 },                         
                        'Location/LD'                             => { 'initial_release' => 51 },                         
                        'Location/Marker'                         => { 'initial_release' => 51 },                         
                        'Location/Compara_Alignments'             => { 'initial_release' => 54 },
                        'Location/Compara_Alignments/Image'       => { 'initial_release' => 56 },
                        'Location/Multi'                          => { 'initial_release' => 56 },
                        'Location/Compara'                        => { 'initial_release' => 62 },
                        'Location/Ensembl_GRCh37'                 => { 'initial_release' => 76 },
                        'Location/Strain'                         => { 'initial_release' => 85 },
                        'Location/Variant_Table'                  => { 'initial_release' => 93 },

                        'Gene/Summary'                            => { 'initial_release' => 51 },                         
                        'Gene/Splice'                             => { 'initial_release' => 51 },                         
                        'Gene/Evidence'                           => { 'initial_release' => 51 },                         
                        'Gene/Sequence'                           => { 'initial_release' => 51 },                         
                        'Gene/Matches'                            => { 'initial_release' => 51 },                         
                        'Gene/Regulation'                         => { 'initial_release' => 51 },
                        'Gene/Ontologies/biological_process'      => { 'initial_release' => 83 },
                        'Gene/Ontologies/molecular_function'      => { 'initial_release' => 83 },
                        'Gene/Ontologies/cellular_component'      => { 'initial_release' => 83 },
                        'Gene/Compara_Alignments'                 => { 'initial_release' => 51 },
                        'Gene/Compara_Tree'                       => { 'initial_release' => 51 },
                        'Gene/Compara_Ortholog'                   => { 'initial_release' => 51 },
                        'Gene/Compara_Ortholog/Alignment'         => { 'initial_release' => 51 },
                        'Gene/Compara_Paralog'                    => { 'initial_release' => 51 },
                        'Gene/Compara_Paralog/Alignment'          => { 'initial_release' => 51 },
                        'Gene/Family'                             => { 'initial_release' => 51 },
                        'Gene/Family/Genes'                       => { 'initial_release' => 51 },
                        'Gene/Family/Alignments'                  => { 'initial_release' => 51 },
                        'Gene/Variation_Gene/Table'               => { 'initial_release' => 51 },
                        'Gene/Variation_Gene/Image'               => { 'initial_release' => 51 },
                        'Gene/ExternalData'                       => { 'initial_release' => 51 },
                        'Gene/UserAnnotation'                     => { 'initial_release' => 51 },
                        'Gene/Idhistory'                          => { 'initial_release' => 51 },
                        'Gene/Compara'                            => { 'initial_release' => 62 },
                        'Gene/StructuralVariation_Gene'           => { 'initial_release' => 63 },
                        'Gene/Phenotype'                          => { 'initial_release' => 64 },
                        'Gene/SpeciesTree'                        => { 'initial_release' => 69 },
                        'Gene/Expression'                         => { 'initial_release' => 71 },
                        'Gene/TranscriptComparison'               => { 'initial_release' => 71 },
                        'Gene/SecondaryStructure'                 => { 'initial_release' => 74 },
                        'Gene/Alleles'                            => { 'initial_release' => 78 },
                        'Gene/ExpressionAtlas'                    => { 'initial_release' => 80 },
                        'Gene/Pathway'                            => { 'initial_release' => 92 },

                        'GeneTree/Image'                          => { 'initial_release' => 60 },

                        'Transcript/Summary'                      => { 'initial_release' => 51 },
                        'Transcript/SupportingEvidence'           => { 'initial_release' => 51 },
                        'Transcript/SupportingEvidence/Alignment' => { 'initial_release' => 51 },
                        'Transcript/Exons'                        => { 'initial_release' => 51 },
                        'Transcript/Sequence_cDNA'                => { 'initial_release' => 51 },
                        'Transcript/Sequence_Protein'             => { 'initial_release' => 51 },
                        'Transcript/Similarity'                   => { 'initial_release' => 51 },
                        'Transcript/Similarity/Align'             => { 'initial_release' => 51 },
                        'Transcript/Oligos'                       => { 'initial_release' => 51 },
                        'Transcript/Population'                   => { 'initial_release' => 51 },
                        'Transcript/Population/Image'             => { 'initial_release' => 51 },
                        'Transcript/ProteinSummary'               => { 'initial_release' => 51 },
                        'Transcript/Domains'                      => { 'initial_release' => 51 },
                        'Transcript/ProtVariations'               => { 'initial_release' => 51 },
                        'Transcript/ExternalData'                 => { 'initial_release' => 51 },
                        'Transcript/UserAnnotation'               => { 'initial_release' => 51 },
                        'Transcript/Idhistory'                    => { 'initial_release' => 51 },
                        'Transcript/Idhistory/Protein'            => { 'initial_release' => 51 },
                        'Transcript/Domains/Genes'                => { 'initial_release' => 52 },
                        'Transcript/GO'                           => { 'renamed' => 'Transcript/Ontology/Table' },
                        'Transcript/Ontology/Table'               => { 'formerly' => { 59 => 'Transcript/GO'} },
                        'Transcript/Ontology/Image'               => { 'initial_release' => 60 },
                        'Transcript/Variation_Transcript/Table'   => { 'initial_release' => 68 },
                        'Transcript/Variation_Transcript/Image'   => { 'initial_release' => 68 },
                        'Transcript/Haplotypes'                   => { 'initial_release' => 84 },
                        'Transcript/Pathway'                      => { 'initial_release' => 92 },
                        'Transcript/PDB'                          => { 'initial_release' => 95 },

                        'Family/Details'                          => { 'initial_release' => 75 },

                        'Variation/Summary'                       => { 'renamed' => 'Variation/Explore' }, 
                        'Variation/Explore'                       => { 'formerly' => { 64 => 'Variation/Summary'} },
                        'Variation/Context'                       => { 'initial_release' => 51 },
                        'Variation/Mappings'                      => { 'initial_release' => 51 },
                        'Variation/Sequence'                      => { 'formerly' => { 68 => 'Variation/Summary'} },
                        'Variation/Population'                    => { 'initial_release' => 51 },
                        'Variation/Compara_Alignments'            => { 'initial_release' => 54 },
                        'Variation/ExternalData'                  => { 'initial_release' => 57 },
                        'Variation/Individual'                    => { 'renamed' => 'Variation/Sample' }, 
                        'Variation/Sample'                        => { 'formerly' => { 80 => 'Variation/Individual'} },
                        'Variation/Phenotype'                     => { 'initial_release' => 57 },
                        'Variation/HighLD'                        => { 'initial_release' => 58 },
                        'Variation/LDPlot'                        => { 'initial_release' => 83 },
                        'Variation/Populations'                   => { 'initial_release' => 60 },
                        'Variation/Explore'                       => { 'initial_release' => 65 },
                        'Variation/Citations'                     => { 'initial_release' => 72 },
                        'Variation/PDB'                           => { 'initial_release' => 95 },

                        'StructuralVariation/Explore'             => { 'initial_release' => 62 },
                        'StructuralVariation/Evidence'            => { 'initial_release' => 62 },
                        'StructuralVariation/Context'             => { 'initial_release' => 60 },
                        'StructuralVariation/Mappings'            => { 'initial_release' => 70 },
                        'StructuralVariation/Phenotype'           => { 'initial_release' => 70 },
			                  'StructuralVariation/Summary'             => { 'renamed' => 'StructuralVariation/Explore' },
                        'StructuralVariation/Explore'             => { 'formerly' => { 64 => 'StructuralVariation/Summary'} },

                        'Regulation/Summary'                      => { 'initial_release' => 56 },
                        'Regulation/Cell_line'                    => { 'initial_release' => 58 },
                        'Regulation/Evidence'                     => { 'initial_release' => 56 },
                        'Regulation/Context'                      => { 'initial_release' => 56 },

                        'LRG/Genome'                              => { 'initial_release' => 58 },
                        'LRG/Summary'                             => { 'initial_release' => 58 },
                        'LRG/Variation_LRG/Table'                 => { 'initial_release' => 58 },
                        'LRG/Differences'                         => { 'initial_release' => 59 },
                        'LRG/Sequence_DNA'                        => { 'initial_release' => 62 },
                        'LRG/Sequence_cDNA'                       => { 'initial_release' => 62 },
                        'LRG/Sequence_Protein'                    => { 'initial_release' => 62 },
                        'LRG/Exons'                               => { 'initial_release' => 62 },
                        'LRG/ProteinSummary'                      => { 'initial_release' => 65 },
                        'LRG/Phenotype'                           => { 'initial_release' => 76 },
                        'LRG/StructuralVariation_LRG'             => { 'initial_release' => 76 },

                        'Phenotype/Locations'                     => { 'initial_release' => 64 },
                        'Phenotype/All'                           => { 'initial_release' => 69 },
                        'Phenotype/RelatedConditions'             => { 'initial_release' => 88 },

                        'Marker/Details'                          => { 'initial_release' => 59 },

                        'Experiment/Sources'                      => { 'initial_release' => 65 },
);

sub get_redirect {
  my ($script, $type, $action) = @_;
  
  if ($script eq 'Page') {
    my $page = $type.'/'.$action;
    return undef unless exists $archive_mapping{$page} && $archive_mapping{$page}{'renamed'};
    return $archive_mapping{$page}{'renamed'};
  }
  else {
    return $script_mapping{$script};
  }
}

sub get_archive_redirect {
  my $url = shift;
  return $archive_mapping{$url};
}

1;
