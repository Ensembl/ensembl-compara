package EnsEMBL::Web::Configuration::Location;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;    }
sub content_panel  { return $_[0]->_content_panel;  }
sub configurator   { return $_[0]->_configurator;   }
sub context_panel  { return $_[0]->_context_panel;  }

sub set_default_action {
  my $self = shift;
  
  if (!ref $self->object) {
    $self->{'_data'}->{'default'} = 'Genome';
    return;
  }
  
  my $x = $self->object->availability || {};
  
  if ($x->{'slice'}) {
    $self->{'_data'}->{'default'} = 'View';
  } elsif ($x->{'chromosome'}) {
    $self->{'_data'}->{'default'} = 'Chromosome';
  } else {
    $self->{'_data'}->{'default'} = 'Genome';
  }
}

sub context_panel {
  my $self   = shift;
  my $object = $self->object;
  
  if ($object->action eq 'Multi') {
    my $panel  = $self->new_panel('Summary',
      'code'    => 'summary_panel',
      'object'  => $object,
      'caption' => $object->caption
    );
    
    $panel->add_component('summary' => 'EnsEMBL::Web::Component::Location::MultiIdeogram');
    $self->add_panel($panel);
  } else {
    $self->_context_panel;
  }
}

sub modify_tree {
  my $self = shift;
  my $object = $self->object;
  my $availability = $object->availability;
  
  # Links to external browsers - UCSC, NCBI, etc
  my %browsers = %{$object->species_defs->EXTERNAL_GENOME_BROWSERS || {}};
  $browsers{'UCSC_DB'} = $object->species_defs->UCSC_GOLDEN_PATH;
  $browsers{'NCBI_DB'} = $object->species_defs->NCBI_GOLDEN_PATH;
  
  my $url;
  my $browser_menu = $self->create_submenu('OtherBrowsers', 'Other genome browsers');
  
  if ($browsers{'UCSC_DB'}) {
    if ($object->seq_region_name) {
      $url = $object->get_ExtURL('EGB_UCSC', { 'UCSC_DB' => $browsers{'UCSC_DB'}, 'CHR' => $object->seq_region_name, 'START' => int($object->seq_region_start), 'END' => int($object->seq_region_end) });
    } else {
      $url = $object->get_ExtURL('EGB_UCSC', { 'UCSC_DB' => $browsers{'UCSC_DB'}, 'CHR' => '1', 'START' => '1', 'END' => '1000000' });
    }
    
    $browser_menu->append($self->create_node('UCSC_DB', 'UCSC', [], { 'availability' => 1, 'url' => $url, 'raw' => 1, 'external' => 1 }));
    
    delete($browsers{'UCSC_DB'});
  }
  
  if ($browsers{'NCBI_DB'}) {
    if ($object->seq_region_name) { 
      $url = $object->get_ExtURL('EGB_NCBI', { 'NCBI_DB' => $browsers{'NCBI_DB'}, 'CHR' => $object->seq_region_name, 'START' => int($object->seq_region_start), 'END' => int($object->seq_region_end) });
    } else {
      my $taxid = $object->species_defs->get_config($object->species, 'TAXONOMY_ID'); 
      $url = "http://www.ncbi.nih.gov/mapview/map_search.cgi?taxid=$taxid";
    }
    
    $browser_menu->append($self->create_node('NCBI_DB', 'NCBI', [], { 'availability' => 1, 'url' => $url, 'raw' => 1, 'external' => 1 }));
    
    delete($browsers{'NCBI_DB'});
  }
  
  foreach (sort keys %browsers) {
    next unless $browsers{$_};
    
    $url = $object->get_ExtURL($_, { 'CHR' => $object->seq_region_name, 'START' => int($object->seq_region_start), 'END' => int($object->seq_region_end) });
    $browser_menu->append($self->create_node($browsers{$_}, $browsers{$_}, [], { 'availability' => 1, 'url' => $url, 'raw' => 1, 'external' => 1 }));
  }
}

sub populate_tree {
  my $self = shift;
  my $object = $self->object;
  my $availability = $object->availability;
  
  $self->create_node('Genome', 'Whole genome',
    [qw( genome EnsEMBL::Web::Component::Location::Genome )],
    { 'availability' => 'karyotype'},
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
      marker EnsEMBL::Web::Component::Location::MarkerDetails
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
