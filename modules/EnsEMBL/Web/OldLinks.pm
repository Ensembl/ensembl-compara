package EnsEMBL::Web::OldLinks;

our @general = qw(assemblyconverter alignview exportview goview historyview fastaview featureview);
our @linking_scripts = qw(
jump_to_contig jump_to_location_view' martlink psychic r);

our %mapping = (
  'alignsliceview'        => { 'type' => 'Location',   'action' => 'Alignslice',    'initial_release' => 1 },
  'colourmap'             => { 'type' => 'Server',     'action' => 'Colourmap',     'initial_release' => 1 },
  'contigview'            => { 'type' => 'Location',   'action' => 'View',          'initial_release' => 1 },
  'cytoview'              => { 'type' => 'Location',   'action' => 'Overview',      'initial_release' => 1 },
  'domainview'            => { 'type' => 'Transcript', 'action' => 'Domain',        'initial_release' => 1 },
  'dotterview'            => { 'type' => 'Location',   'action' => 'Dotter',        'initial_release' => 1 },
  'exonview'              => { 'type' => 'Transcript', 'action' => 'Exons',         'initial_release' => 1 },
  'familyview'            => { 'type' => 'Gene',       'action' => 'Family',        'initial_release' => 1 },
  'generegulationview'    => { 'type' => 'Gene',       'action' => 'Regulation',    'initial_release' => 1 },
  'geneseqalignview'      => { 'type' => 'Gene',       'action' => 'SeqAlign',      'initial_release' => 1 },
  'geneseqview'           => { 'type' => 'Gene',       'action' => 'Seq',           'initial_release' => 1 },
  'genesnpview'           => { 'type' => 'Gene',       'action' => 'Variation',     'initial_release' => 1 },
  'genespliceview'        => { 'type' => 'Gene',       'action' => 'Splice',        'initial_release' => 1 },
  'genetreeview'          => { 'type' => 'Gene',       'action' => 'Tree',          'initial_release' => 1 },
  'geneview'              => { 'type' => 'Gene',       'action' => 'Summary',       'initial_release' => 1 },
  'helpview'              => { 'type' => 'Help',       'action' => 'Help',          'initial_release' => 1 },
  'idhistoryview'         => { 'type' => 'Gene',       'action' => 'History',       'initial_release' => 1 },
  'karyoview'             => { 'type' => 'Location',   'action' => 'Karyotype',     'initial_release' => 1 },
  'ldtableview'           => { 'type' => 'Location',   'action' => 'LDtable',       'initial_release' => 1 },
  'ldview'                => { 'type' => 'Location',   'action' => 'LD',            'initial_release' => 1 },
  'mapview'               => { 'type' => 'Location',   'action' => 'Map',           'initial_release' => 1 },
  'markerview'            => { 'type' => 'Location',   'action' => 'Marker',        'initial_release' => 1 },
  'miscsetview'           => { 'type' => 'Location',   'action' => 'Miscset',       'initial_release' => 1 },
  'multicontigview'       => { 'type' => 'Location',   'action' => 'Multi',         'initial_release' => 1 },
  'protview'              => { 'type' => 'Transcript', 'action' => 'Protein',       'initial_release' => 1 },
  'search'                => { 'type' => 'Search',     'action' => 'Summary',       'initial_release' => 1 },
  'sequencealignview'     => { 'type' => 'Location',   'action' => 'SeqAlign',      'initial_release' => 1 },
  'snpview'               => { 'type' => 'Variation',  'action' => 'Summary',       'initial_release' => 1 },
  'status'                => { 'type' => 'Server',     'action' => 'Status',        'initial_release' => 1 },
  'syntenyview'           => { 'type' => 'Location',   'action' => 'Synteny',       'initial_release' => 1 },
  'transcriptsnpdataview' => { 'type' => 'Transcript', 'action' => 'Variationdata', 'initial_release' => 1 },
  'transcriptsnpview'     => { 'type' => 'Transcript', 'action' => 'Variation',     'initial_release' => 1 },
  'transview'             => { 'type' => 'Transcript', 'action' => 'Summary',       'initial_release' => 1 }
);

sub new { 
  my $self = shift;
}

sub get_redirect {
  my( $self, $old_name ) = @_;
  return undef unless exists $mapping{ $old_name };
  return $mapping{ $old_name }{ 'type' }.'/'.$mapping{ $old_name }{ 'action' }
}

1;
