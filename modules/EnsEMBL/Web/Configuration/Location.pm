package EnsEMBL::Web::Configuration::Location;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;    }
sub content_panel  { return $_[0]->_content_panel;  }
sub configurator   { return $_[0]->_configurator;   }

sub context_panel {
  my $self  = shift;
  my $model = $self->model;
  
  if ($model->hub->action eq 'Multi') {
    my $panel  = $self->new_panel('Summary',
      'code'    => 'summary_panel',
      'object'  => $model->object,
      'caption' => $self->caption
    );
    
    $panel->add_component('summary' => 'EnsEMBL::Web::Component::Location::MultiIdeogram');
    $self->add_panel($panel);
  } else {
    $self->_context_panel;
  }
}

sub set_default_action {
  my $self = shift;
  
  if (!$self->object) {
    $self->{'_data'}->{'default'} = 'Genome';
    return;
  }
  
  my $avail = $self->availability || {};
  
  if ($avail->{'slice'}) {
    $self->{'_data'}->{'default'} = 'View';
  } 
  elsif ($avail->{'chromosome'}) {
    $self->{'_data'}->{'default'} = 'Chromosome';
  } 
  else {
    $self->{'_data'}->{'default'} = 'Genome';
  }
}

sub short_caption {
  my $self = shift;
  return 'Location-based displays';
}

sub caption {
  my $self = shift;
  my $location = $self->model->object('Location');
  
  return 'Karyotype' unless $location && $location->seq_region_name;
  
  return $location->neat_sr_name($location->seq_region_type, $location->seq_region_name) . ': ' . 
         $location->thousandify($location->seq_region_start) . '-' . 
         $location->thousandify($location->seq_region_end);
}

sub availability {
  my $self = shift;
  my $hub = $self->model->hub;

  if (!$self->{'_availability'}) {
    my $availability = $self->default_availability;

    my ($marker_rows, $seq_region_name, $counts);

    ## Only available on specific regions (e.g. not whole genome)
    my $location = $self->model->object('Location');
    
    if ($location) {
      $marker_rows              = $location->table_info($location->get_db, 'marker_feature')->{'rows'};
      $seq_region_name          = $self->model->api_object('Location')->{'seq_region_name'};
      $counts                   = $self->counts;
      $availability->{"has_$_"} = $counts->{$_} for qw(alignments pairwise_alignments);
    }

    ## Applicable to all location-based pages
    my $species_defs = $hub->species_defs;
    my $variation_db = $species_defs->databases->{'DATABASE_VARIATION'};
    my @chromosomes  = @{$species_defs->ENSEMBL_CHROMOSOMES || []};
    my %chrs         = map { $_, 1 } @chromosomes;
    my %synteny_hash = $species_defs->multi('DATABASE_COMPARA', 'SYNTENY');

    $availability->{'karyotype'}       = 1;
    $availability->{'chromosome'}      = exists $chrs{$seq_region_name};
    $availability->{'has_chromosomes'} = scalar @chromosomes;
    $availability->{'has_strains'}     = $variation_db && $variation_db->{'#STRAINS'};
    $availability->{'slice'}           = $seq_region_name && $seq_region_name ne $hub->core_param('r');
    $availability->{'has_synteny'}     = scalar keys %{$synteny_hash{$self->species} || {}};
    $availability->{'has_LD'}          = $variation_db && $variation_db->{'DEFAULT_LD_POP'};
    $availability->{'has_markers'}     = ($hub->param('m') || $hub->param('r')) && $marker_rows;

    $self->{'_availability'} = $availability;
  }

  return $self->{'_availability'};
}

sub counts {
  my $self = shift;
  my $hub = $self->model->hub;

  my $key    = '::COUNTS::LOCATION::' . $hub->species;
  my $counts = $self->{'_counts'};
  $counts  ||= $hub->cache->get($key) if $hub->cache;

  if (!$counts) {
    my %synteny    = $hub->species_defs->multi('DATABASE_COMPARA', 'SYNTENY');
    my $alignments = $self->count_alignments;

    $counts = {
      synteny             => scalar keys %{$synteny{$hub->species}||{}},
      alignments          => $alignments->{'all'},
      pairwise_alignments => $alignments->{'pairwise'}
    };

    $counts->{'reseq_strains'} = $hub->species_defs->databases->{'DATABASE_VARIATION'}{'#STRAINS'} if $hub->species_defs->databases->{'DATABASE_VARIATION'};

    $counts = {%$counts, %{$self->_counts}};

    $hub->cache->set($key, $counts, undef, 'COUNTS') if $hub->cache;
    $self->{'_counts'} = $counts;
  }

  return $counts;
}

sub modify_tree {
  my $self = shift;
  my $location = $self->model->object('Location');
  my $hub = $self->model->hub;
  
  # Links to external browsers - UCSC, NCBI, etc
  my %browsers = %{$hub->species_defs->EXTERNAL_GENOME_BROWSERS || {}};
  $browsers{'UCSC_DB'} = $hub->species_defs->UCSC_GOLDEN_PATH;
  $browsers{'NCBI_DB'} = $hub->species_defs->NCBI_GOLDEN_PATH;
  
  my $url;
  my $browser_menu = $self->create_submenu('OtherBrowsers', 'Other genome browsers');
  
  if ($browsers{'UCSC_DB'}) {
    if ($location && $location->seq_region_name) {
      $url = $hub->get_ExtURL('EGB_UCSC', { 'UCSC_DB' => $browsers{'UCSC_DB'}, 'CHR' => $location->seq_region_name, 'START' => int($location->seq_region_start), 'END' => int($location->seq_region_end) });
    } else {
      $url = $hub->get_ExtURL('EGB_UCSC', { 'UCSC_DB' => $browsers{'UCSC_DB'}, 'CHR' => '1', 'START' => '1', 'END' => '1000000' });
    }
    
    $browser_menu->append($self->create_node('UCSC_DB', 'UCSC', [], { 'availability' => 1, 'url' => $url, 'raw' => 1, 'external' => 1 }));
    
    delete($browsers{'UCSC_DB'});
  }
  
  if ($browsers{'NCBI_DB'}) {
    if ($location && $location->seq_region_name) { 
      $url = $hub->get_ExtURL('EGB_NCBI', { 'NCBI_DB' => $browsers{'NCBI_DB'}, 'CHR' => $location->seq_region_name, 'START' => int($location->seq_region_start), 'END' => int($location->seq_region_end) });
    } else {
      my $taxid = $hub->species_defs->get_config($hub->species, 'TAXONOMY_ID'); 
      $url = "http://www.ncbi.nih.gov/mapview/map_search.cgi?taxid=$taxid";
    }
    
    $browser_menu->append($self->create_node('NCBI_DB', 'NCBI', [], { 'availability' => 1, 'url' => $url, 'raw' => 1, 'external' => 1 }));
    
    delete($browsers{'NCBI_DB'});
  }
  
  foreach (sort keys %browsers) {
    next unless $browsers{$_};
    
    $url = $hub->get_ExtURL($_, { 'CHR' => $location->seq_region_name, 'START' => int($location->seq_region_start), 'END' => int($location->seq_region_end) });
    $browser_menu->append($self->create_node($browsers{$_}, $browsers{$_}, [], { 'availability' => 1, 'url' => $url, 'raw' => 1, 'external' => 1 }));
  }
}

sub populate_tree {
  my $self = shift;
  
  $self->create_node('Genome', 'Whole genome',
    [qw( genome EnsEMBL::Web::Component::Location::Genome )],
    { 'availability' => 1},
  );

  $self->create_node('Chromosome', 'Chromosome summary',
    [qw(
      image  EnsEMBL::Web::Component::Location::ChromosomeImage
      change EnsEMBL::Web::Component::Location::ChangeChromosome
      stats  EnsEMBL::Web::Component::Location::ChromosomeStats
    )],
    { 'availability' => 'chromosome', 'disabled' => 'This sequence region is not part of an assembled chromosome' }
  );

  $self->create_node('Overview', 'Region overview',
    [qw(
      nav EnsEMBL::Web::Component::Location::ViewBottomNav/region
      top EnsEMBL::Web::Component::Location::Region
    )],
    { 'availability' => 'slice'}
  );

  $self->create_node('View', 'Region in detail',
    [qw(
      top    EnsEMBL::Web::Component::Location::ViewTop
      botnav EnsEMBL::Web::Component::Location::ViewBottomNav
      bottom EnsEMBL::Web::Component::Location::ViewBottom
    )],
    { 'availability' => 'slice' }
  );

  my $align_menu = $self->create_submenu('Compara', 'Comparative Genomics');
  
  $align_menu->append($self->create_node('Compara_Alignments/Image', 'Alignments (image) ([[counts::alignments]])', 
    [qw(
      top      EnsEMBL::Web::Component::Location::ViewTop
      selector EnsEMBL::Web::Component::Compara_AlignSliceSelector
      botnav   EnsEMBL::Web::Component::Location::ViewBottomNav
      bottom   EnsEMBL::Web::Component::Location::Compara_AlignSliceBottom
    )],
    { 'availability' => 'slice database:compara has_alignments', 'concise' => 'Alignments (image)' }
  ));
  
  $align_menu->append($self->create_node('Compara_Alignments', 'Alignments (text) ([[counts::alignments]])',
    [qw(
      selector   EnsEMBL::Web::Component::Compara_AlignSliceSelector
      botnav     EnsEMBL::Web::Component::Location::ViewBottomNav
      alignments EnsEMBL::Web::Component::Location::Compara_Alignments
    )],
    { 'availability' => 'slice database:compara has_alignments', 'concise' => 'Alignments (text)' }
  ));
  
  $align_menu->append($self->create_node('Multi', 'Multi-species view ([[counts::pairwise_alignments]])',
    [qw(
      selector EnsEMBL::Web::Component::Location::MultiSpeciesSelector
      top      EnsEMBL::Web::Component::Location::MultiTop
      botnav   EnsEMBL::Web::Component::Location::MultiBottomNav
      bottom   EnsEMBL::Web::Component::Location::MultiBottom
    )],
    { 'availability' => 'slice database:compara has_pairwise_alignments', 'concise' => 'Multi-species view' }
  ));
  
  $align_menu->append($self->create_subnode('ComparaGenomicAlignment', '',
    [qw( gen_alignment EnsEMBL::Web::Component::Location::ComparaGenomicAlignment )],
    { 'no_menu_entry' => 1 }
  ));
  
  $align_menu->append($self->create_node('Synteny', 'Synteny ([[counts::synteny]])',
    [qw(
      image    EnsEMBL::Web::Component::Location::SyntenyImage
      species  EnsEMBL::Web::Component::Location::ChangeSpecies
      change   EnsEMBL::Web::Component::Location::ChangeChromosome
      homo_nav EnsEMBL::Web::Component::Location::NavigateHomology
      matches  EnsEMBL::Web::Component::Location::SyntenyMatches
    )],
    { 'availability' => 'chromosome has_synteny', 'concise' => 'Synteny' }
  ));
  
  my $variation_menu = $self->create_submenu( 'Variation', 'Genetic Variation' );
  
  $variation_menu->append($self->create_node('SequenceAlignment', 'Resequencing ([[counts::reseq_strains]])',
    [qw(
      botnav EnsEMBL::Web::Component::Location::ViewBottomNav
            align  EnsEMBL::Web::Component::Location::SequenceAlignment
    )],
    { 'availability' => 'slice has_strains', 'concise' => 'Resequencing Alignments' }
  ));
  $variation_menu->append($self->create_node('LD', 'Linkage Data',
    [qw(
      pop     EnsEMBL::Web::Component::Location::SelectPopulation
      ld      EnsEMBL::Web::Component::Location::LD
      ldnav   EnsEMBL::Web::Component::Location::ViewBottomNav
      ldimage EnsEMBL::Web::Component::Location::LDImage
    )],
    { 'availability' => 'slice has_LD', 'concise' => 'Linkage Disequilibrium Data' }
  ));

  $self->create_node('Marker', 'Markers',
    [qw(
      botnav EnsEMBL::Web::Component::Location::ViewBottomNav
      marker EnsEMBL::Web::Component::Location::Markers
    )],
    { 'availability' => 'slice|marker has_markers' }
  );

  $self->create_subnode(
    'Export', '',
    [qw( export EnsEMBL::Web::Component::Export::Location )],
    { 'availability' => 'slice', 'no_menu_entry' => 1 }
  );
}

1;
