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

package EnsEMBL::Web::OldLinks;

use strict;

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(get_redirect get_archive_redirect);

our %mapping = (
  'blastview'             => [{ 'type' => 'Tools',               'action' => 'Blast',                        'initial_release' => 76 }],
  'featureview'           => [{ 'type' => 'Location',            'action' => 'Genome',                       'initial_release' => 34 }],
  'karyoview'             => [{ 'type' => 'Location',            'action' => 'Genome',                       'initial_release' => 1, 'final_release' => 31 }],
  'mapview'               => [{ 'type' => 'Location',            'action' => 'Chromosome',                   'initial_release' => 1  }],
  'cytoview'              => [{ 'type' => 'Location',            'action' => 'Overview',                     'initial_release' => 1  }],
  'contigview'            => [{ 'type' => 'Location',            'action' => 'View',                         'initial_release' => 1  }],
  'sequencealignview'     => [{ 'type' => 'Location',            'action' => 'SequenceAlignment',            'initial_release' => 46 }],
  'syntenyview'           => [{ 'type' => 'Location',            'action' => 'Synteny',                      'initial_release' => 1  }],
  'markerview'            => [{ 'type' => 'Location',            'action' => 'Marker',                       'initial_release' => 1  }],
  'ldview'                => [{ 'type' => 'Location',            'action' => 'LD',                           'initial_release' => 50 }],
  'multicontigview'       => [{ 'type' => 'Location',            'action' => 'Multi',                        'initial_release' => 1 , 'missing_releases' => [51..55] }],
  'alignsliceview'        => [{ 'type' => 'Location',            'action' => 'Compara_Alignments/Image',     'initial_release' => 34, 'missing_releases' => [51..55] }],
  'Compara_Alignments' => [{ type => 'Location', 'action' => 'ComparaGenomicAlignment', initial_release => 68, }],
  'geneview'              => [{ 'type' => 'Gene',                'action' => 'Summary',                      'initial_release' => 1  },
                              { type => 'Gene', action => 'SecondaryStructure', initial_release => 74 },
                              { 'type' => 'Gene',                'action' => 'Matches',                      'initial_release' => 1  },
                              { 'type' => 'Gene',                'action' => 'Compara_Ortholog',             'initial_release' => 1  },
                              { 'type' => 'Gene',                'action' => 'Compara_Paralog',              'initial_release' => 1  },
                              { 'type' => 'Gene',                'action' => 'ExternalData',                 'initial_release' => 1  },
                              { 'type' => 'Gene',                'action' => 'UserAnnotation',               'initial_release' => 1  }],
  'genespliceview'        => [{ 'type' => 'Gene',                'action' => 'Splice',                       'initial_release' => 34 }],
  'geneseqview'           => [{ 'type' => 'Gene',                'action' => 'Sequence',                     'initial_release' => 34 }],
  'generegulationview'    => [{ 'type' => 'Gene',                'action' => 'Regulation',                   'initial_release' => 34 }],
  'geneseqalignview'      => [{ 'type' => 'Gene',                'action' => 'Compara_Alignments',           'initial_release' => 1  }],
  'genetree'              => [{ 'type' => 'Gene',                'action' => 'Compara_Tree',                 'initial_release' => 51 },
                              { 'type' => 'Gene',                'action' => 'Compara_Tree/Text',            'initial_release' => 51 },
                              { 'type' => 'Gene',                'action' => 'Compara_Tree/Align',           'initial_release' => 51 }],
  'familyview'            => [{ 'type' => 'Gene',                'action' => 'Family',                       'initial_release' => 1  }],
  'genesnpview'           => [{ 'type' => 'Gene',                'action' => 'Variation_Gene',               'initial_release' => 1  },
                              { 'type' => 'Gene',                'action' => 'Variation_Gene/Table',         'initial_release' => 1  },
                              { 'type' => 'Gene',                'action' => 'Variation_Gene/Image',         'initial_release' => 1  }],
  'idhistoryview'         => [{ 'type' => 'Gene',                'action' => 'Idhistory',                    'initial_release' => 39 },
                              { 'type' => 'Transcript',          'action' => 'Idhistory',                    'initial_release' => 39 },
                              { 'type' => 'Transcript',          'action' => 'Idhistory/Protein',            'initial_release' => 39 }],
  'transview'             => [{ 'type' => 'Transcript',          'action' => 'Summary',                      'initial_release' => 1  },
                              { 'type' => 'Transcript',          'action' => 'Sequence_cDNA',                'initial_release' => 1  },
                              { 'type' => 'Transcript',          'action' => 'Similarity',                   'initial_release' => 1  },
                              { 'type' => 'Transcript',          'action' => 'Oligos',                       'initial_release' => 1  },
                              { 'type' => 'Transcript',          'action' => 'GO',                           'initial_release' => 1  },
                              { 'type' => 'Transcript',          'action' => 'ExternalData',                 'initial_release' => 1  },
                              { 'type' => 'Transcript',          'action' => 'UserAnnotation',               'initial_release' => 1  }],
  'exonview'              => [{ 'type' => 'Transcript',          'action' => 'Exons',                        'initial_release' => 1  },
                              { 'type' => 'Transcript',          'action' => 'SupportingEvidence',           'initial_release' => 1  }],
  'protview'              => [{ 'type' => 'Transcript',          'action' => 'ProteinSummary',               'initial_release' => 1  },
                              { 'type' => 'Transcript',          'action' => 'Domains',                      'initial_release' => 1  },
                              { 'type' => 'Transcript',          'action' => 'Sequence_Protein',             'initial_release' => 1  },
                              { 'type' => 'Transcript',          'action' => 'ProtVariations',               'initial_release' => 1  }],
  'transcriptsnpview'     => [{ 'type' => 'Transcript',          'action' => 'Population',                   'initial_release' => 37 },
                              { 'type' => 'Transcript',          'action' => 'Population/Image',             'initial_release' => 37 }],
  'domainview'            => [{ 'type' => 'Transcript',          'action' => 'Domains/Genes',                'initial_release' => 1  }],
  'alignview'             => [{ 'type' => 'Transcript',          'action' => 'SupportingEvidence/Alignment', 'initial_release' => 1  },
                              { 'type' => 'Transcript',          'action' => 'Similarity/Align',             'initial_release' => 1  }],
  'snpview'               => [{ 'type' => 'Variation',           'action' => 'Summary',                      'initial_release' => 1  }],
  'searchview'            => [{ 'type' => 'Search',              'action' => 'Results',                      'initial_release' => 1  }],
  'search'                => [{ 'type' => 'Search',              'action' => 'Results',                      'initial_release' => 1  }],
  
  'new_views'             => [{ 'type' => 'Location',            'action' => 'Compara_Alignments',           'initial_release' => 54 },
                              { 'type' => 'Location',            'action' => 'Compara',                      'initial_release' => 62 },
                              { 'type' => 'Variation',           'action' => 'Sequence',                     'initial_release' => 51 },
                              { 'type' => 'Variation',           'action' => 'Mappings',                     'initial_release' => 51 },
                              { 'type' => 'Variation',           'action' => 'Population',                   'initial_release' => 51 },
                              { 'type' => 'Variation',           'action' => 'Populations',                  'initial_release' => 60 },
                              { 'type' => 'Variation',           'action' => 'Individual',                   'initial_release' => 51 },
                              { 'type' => 'Variation',           'action' => 'Context',                      'initial_release' => 51 },
                              { 'type' => 'Variation',           'action' => 'Phenotype',                    'initial_release' => 57 },
                              { 'type' => 'Variation',           'action' => 'HighLD',                       'initial_release' => 58 },
                              { 'type' => 'Variation',           'action' => 'Compara_Alignments',           'initial_release' => 54 },
                              { 'type' => 'Variation',           'action' => 'Explore',                      'initial_release' => 65 },
                              { 'type' => 'Variation',           'action' => 'ExternalData',                 'initial_release' => 57 },
                              { 'type' => 'Variation',           'action' => 'Citations',                    'initial_release' => 72 },
                              { 'type' => 'StructuralVariation', 'action' => 'Explore',                      'initial_release' => 62 },
                              { 'type' => 'StructuralVariation', 'action' => 'Evidence',                     'initial_release' => 62 },
                              { 'type' => 'StructuralVariation', 'action' => 'Context',                      'initial_release' => 60 },
                              { 'type' => 'StructuralVariation', 'action' => 'Mappings',                     'initial_release' => 70 },
                              { 'type' => 'StructuralVariation', 'action' => 'Phenotype',                    'initial_release' => 70 },
                              { 'type' => 'Regulation',          'action' => 'Summary',                      'initial_release' => 56 },
                              { 'type' => 'Regulation',          'action' => 'Cell_line',                    'initial_release' => 58 },
                              { 'type' => 'Regulation',          'action' => 'Evidence',                     'initial_release' => 56 },
                              { 'type' => 'Regulation',          'action' => 'Context',                      'initial_release' => 56 },
                              { 'type' => 'Gene',                'action' => 'Evidence',                     'initial_release' => 51 },
                              { 'type' => 'Gene',                'action' => 'Phenotype',                    'initial_release' => 64 },
                              { 'type' => 'Gene',                'action' => 'Compara',                      'initial_release' => 62 },
                              { 'type' => 'Gene',                'action' => 'StructuralVariation_Gene',     'initial_release' => 63 },
                              { 'type' => 'Gene',                'action' => 'TranscriptComparison',         'initial_release' => 71 },
                              { 'type' => 'Gene',                'action' => 'Expression',                   'initial_release' => 71 },
                              { 'type' => 'Gene',                'action' => 'SpeciesTree',                  'initial_release' => 69 },
                              { 'type' => 'Gene',                'action' => 'Alleles',                      'initial_release' => 78 },
                              { 'type' => 'Gene',                'action' => 'ExpressionAtlas',              'initial_release' => 80 },
                              { 'type' => 'Transcript',          'action' => 'Ontology/Image',               'initial_release' => 60 },
                              { 'type' => 'Transcript',          'action' => 'Ontology/Table',               'initial_release' => 60 },
                              { 'type' => 'Transcript',          'action' => 'Variation_Transcript/Table',   'initial_release' => 68 },
                              { 'type' => 'Transcript',          'action' => 'Variation_Transcript/Image',   'initial_release' => 68 },
                              { 'type' => 'LRG',                 'action' => 'Genome',                       'initial_release' => 58 },
                              { 'type' => 'LRG',                 'action' => 'Summary',                      'initial_release' => 58 },
                              { 'type' => 'LRG',                 'action' => 'Variation_LRG/Table',          'initial_release' => 58 },
                              { 'type' => 'LRG',                 'action' => 'Differences',                  'initial_release' => 59 },
                              { 'type' => 'LRG',                 'action' => 'Sequence_DNA',                 'initial_release' => 62 },
                              { 'type' => 'LRG',                 'action' => 'Sequence_cDNA',                'initial_release' => 62 },
                              { 'type' => 'LRG',                 'action' => 'Sequence_Protein',             'initial_release' => 62 },
                              { 'type' => 'LRG',                 'action' => 'Exons',                        'initial_release' => 62 },
                              { 'type' => 'LRG',                 'action' => 'ProteinSummary',               'initial_release' => 65 },
                              { 'type' => 'LRG',                 'action' => 'Phenotype',                    'initial_release' => 76 },
                              { 'type' => 'LRG',                 'action' => 'StructuralVariation_LRG',      'initial_release' => 76 },
                              { 'type' => 'Phenotype',           'action' => 'Locations',                    'initial_release' => 64 },
                              { 'type' => 'Phenotype',           'action' => 'All',                          'initial_release' => 69 },
                              { 'type' => 'Marker',              'action' => 'Details',                      'initial_release' => 59 },
                              { 'type' => 'GeneTree',            'action' => 'Image',                        'initial_release' => 60 },
                              { 'type' => 'Family',              'action' => 'Details',                      'initial_release' => 75 },
                              { 'type' => 'Experiment',          'action' => 'Sources',                      'initial_release' => 65 },
                              { 'type' => 'Search',              'action' => 'New',                          'initial_release' => 63 }],       
  # internal views
  'colourmap'             => [{ 'type' => 'Server',              'action' => 'Colourmap',                    'initial_release' => 1  }],
  'status'                => [{ 'type' => 'Server',              'action' => 'Information',                  'initial_release' => 34 }],
  # still to be reintroduced (as of e56)
  'dotterview'            => [{ 'type' => 'Location',            'action' => 'Dotter',                       'initial_release' => 1  }],
  # redundant?          
  'dasconfview'           => [{ 'type' => 'UserData',            'action' => 'Attach',                       'initial_release' => 1  }],
  'helpview'              => [{ 'type' => 'Help',                'action' => 'Search',                       'initial_release' => 34 }],
  'miscsetview'           => [{ 'type' => 'Location',            'action' => 'Miscset',                      'initial_release' => 34 }],

  # Renamed
  'Variation/Individual'  => [{ 'type' => 'Variation',           'action' => 'Sample',                        'initial_release' => 81 }],
);

sub get_redirect {
  my ($old_name) = @_;
  
  return undef unless exists $mapping{$old_name};
  return "$mapping{$old_name}[0]{'type'}/$mapping{$old_name}[0]{'action'}";
}

sub get_archive_redirect {
  my ($type, $action) = @_;
  my @releases;
  
  while (my ($old_view, $new_views) = each %mapping) {
    push @releases, [ $old_view, $_->{'initial_release'}, $_->{'final_release'}, $_->{'missing_releases'} || [] ] for grep $_->{'type'} eq $type && $_->{'action'} eq $action, @$new_views;
  }
  
  return \@releases;
}

1;
