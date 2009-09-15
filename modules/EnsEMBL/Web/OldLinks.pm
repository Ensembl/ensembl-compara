package EnsEMBL::Web::OldLinks;

use strict;

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(get_archive_redirect get_redirect);

our %mapping = (
  'featureview'           => [{ 'type' => 'Location',   'action' => 'Genome',                       'initial_release' => 34 }],
  'karyoview'             => [{ 'type' => 'Location',   'action' => 'Genome',                       'initial_release' => 1, 'final_release' => 31 }],
  'mapview'               => [{ 'type' => 'Location',   'action' => 'Chromosome',                   'initial_release' => 1  }],
  'cytoview'              => [{ 'type' => 'Location',   'action' => 'Overview',                     'initial_release' => 1  }],
  'contigview'            => [{ 'type' => 'Location',   'action' => 'View',                         'initial_release' => 1  }],
  'sequencealignview'     => [{ 'type' => 'Location',   'action' => 'SequenceAlignment',            'initial_release' => 46 }],
  'syntenyview'           => [{ 'type' => 'Location',   'action' => 'Synteny',                      'initial_release' => 1  }],
  'markerview'            => [{ 'type' => 'Location',   'action' => 'Marker',                       'initial_release' => 1  }],
  'ldview'                => [{ 'type' => 'Location',   'action' => 'LD',                           'initial_release' => 50 }],
  'multicontigview'       => [{ 'type' => 'Location',   'action' => 'Multi',                        'initial_release' => 1 , 'missing_releases' => [51..55] }],
  'alignsliceview'        => [{ 'type' => 'Location',   'action' => 'Compara_Alignments/Image',     'initial_release' => 34, 'missing_releases' => [51..55] }],
  'geneview'              => [{ 'type' => 'Gene',       'action' => 'Summary',                      'initial_release' => 1  },
                              { 'type' => 'Gene',       'action' => 'Matches',                      'initial_release' => 1  },
                              { 'type' => 'Gene',       'action' => 'Compara_Ortholog',             'initial_release' => 1  },
                              { 'type' => 'Gene',       'action' => 'Compara_Paralog',              'initial_release' => 1  },
                              { 'type' => 'Gene',       'action' => 'ExternalData',                 'initial_release' => 1  },
                              { 'type' => 'Gene',       'action' => 'UserAnnotation',               'initial_release' => 1  }],
  'genespliceview'        => [{ 'type' => 'Gene',       'action' => 'Splice',                       'initial_release' => 34 }],
  'geneseqview'           => [{ 'type' => 'Gene',       'action' => 'Sequence',                     'initial_release' => 34 }],
  'generegulationview'    => [{ 'type' => 'Gene',       'action' => 'Regulation',                   'initial_release' => 34 }],
  'geneseqalignview'      => [{ 'type' => 'Gene',       'action' => 'Compara_Alignments',           'initial_release' => 1  }],
  'genetree'              => [{ 'type' => 'Gene',       'action' => 'Compara_Tree',                 'initial_release' => 51 },
                              { 'type' => 'Gene',       'action' => 'Compara_Tree/Text',            'initial_release' => 51 },
                              { 'type' => 'Gene',       'action' => 'Compara_Tree/Align',           'initial_release' => 51 }],
  'familyview'            => [{ 'type' => 'Gene',       'action' => 'Family',                       'initial_release' => 1  }],
  'genesnpview'           => [{ 'type' => 'Gene',       'action' => 'Variation_Gene',               'initial_release' => 1  },
                              { 'type' => 'Gene',       'action' => 'Variation_Gene/Table',         'initial_release' => 1  }],
  'idhistoryview'         => [{ 'type' => 'Gene',       'action' => 'Idhistory',                    'initial_release' => 39 },
                              { 'type' => 'Transcript', 'action' => 'Idhistory',                    'initial_release' => 39 },
                              { 'type' => 'Transcript', 'action' => 'Idhistory/Protein',            'initial_release' => 39 }],
  'transview'             => [{ 'type' => 'Transcript', 'action' => 'Summary',                      'initial_release' => 1  },
                              { 'type' => 'Transcript', 'action' => 'Sequence_cDNA',                'initial_release' => 1  },
                              { 'type' => 'Transcript', 'action' => 'Similarity',                   'initial_release' => 1  },
                              { 'type' => 'Transcript', 'action' => 'Oligos',                       'initial_release' => 1  },
                              { 'type' => 'Transcript', 'action' => 'GO',                           'initial_release' => 1  },
                              { 'type' => 'Transcript', 'action' => 'ExternalData',                 'initial_release' => 1  },
                              { 'type' => 'Transcript', 'action' => 'UserAnnotation',               'initial_release' => 1  }],
  'exonview'              => [{ 'type' => 'Transcript', 'action' => 'Exons',                        'initial_release' => 1  },
                              { 'type' => 'Transcript', 'action' => 'SupportingEvidence',           'initial_release' => 1  }],
  'protview'              => [{ 'type' => 'Transcript', 'action' => 'ProteinSummary',               'initial_release' => 1  },
                              { 'type' => 'Transcript', 'action' => 'Domains',                      'initial_release' => 1  },
                              { 'type' => 'Transcript', 'action' => 'Sequence_Protein',             'initial_release' => 1  },
                              { 'type' => 'Transcript', 'action' => 'ProtVariations',               'initial_release' => 1  }],
  'transcriptsnpview'     => [{ 'type' => 'Transcript', 'action' => 'Population',                   'initial_release' => 37 },
                              { 'type' => 'Transcript', 'action' => 'Population/Image',             'initial_release' => 37 }],
  'domainview'            => [{ 'type' => 'Transcript', 'action' => 'Domains/Genes',                'initial_release' => 1  }],
  'alignview'             => [{ 'type' => 'Transcript', 'action' => 'SupportingEvidence/Alignment', 'initial_release' => 1  },
                              { 'type' => 'Transcript', 'action' => 'Similarity/Align',             'initial_release' => 1  }],
  'snpview'               => [{ 'type' => 'Variation',  'action' => 'Summary',                      'initial_release' => 1  }],
  'searchview'            => [{ 'type' => 'Search',     'action' => 'Summary',                      'initial_release' => 1  }],
  'search'                => [{ 'type' => 'Search',     'action' => 'Summary',                      'initial_release' => 1  }],
  'new_views'             => [{ 'type' => 'Location',   'action' => 'Compara_Alignments',           'initial_release' => 54 },
                          =>  { 'type' => 'Variation',  'action' => 'Compara_Alignments',           'initial_release' => 54 },
                              { 'type' => 'Gene',       'action' => 'Evidence',                     'initial_release' => 51 }],
  # internal views
  'colourmap'             => [{ 'type' => 'Server',     'action' => 'Colourmap',                    'initial_release' => 1  }],
  'status'                => [{ 'type' => 'Server',     'action' => 'Information',                  'initial_release' => 34 }],
  # still to be reintroduced (as of e56)
  'dotterview'            => [{ 'type' => 'Location',   'action' => 'Dotter',                       'initial_release' => 1  }],
  # redundant?
  'dasconfview'           => [{ 'type' => 'UserData',   'action' => 'Attach',                       'initial_release' => 1  }],
  'helpview'              => [{ 'type' => 'Help',       'action' => 'Search',                       'initial_release' => 34 }],
  'miscsetview'           => [{ 'type' => 'Location',   'action' => 'Miscset',                      'initial_release' => 34 }],
);

sub get_redirect {
  my ($old_name) = @_;
  
  return undef unless exists $mapping{$old_name};
  return "$mapping{$old_name}[0]{'type'}/$mapping{$old_name}[0]{'action'}";
}

sub get_archive_redirect {
  my ($type, $action, $object) = @_;
  
  my $releases;
  
  while (my ($old_view, $new_views) = each (%mapping)) {
    foreach (@$new_views) {
      if ($_->{'type'} eq $type && $_->{'action'} eq $action) {
        my $final_release = $_->{'final_release'} || $object ? $object->species_defs->ENSEMBL_VERSION : undef;
        
        push @$releases, [ $old_view, $_->{'initial_release'}, $final_release, $_->{'missing_releases'} || [] ];
      }
    }
  }
  
  return $releases;
}

1;
