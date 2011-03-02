# $Id$ 

package EnsEMBL::Web::Configuration::Location;

use strict;

use Bio::EnsEMBL::Registry;

use base qw(EnsEMBL::Web::Configuration);

sub caption { return 'Karyotype'; }

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = $self->object ? $self->object->default_action : 'Genome';
}

sub populate_tree {
  my $self = shift;
  
  $self->create_node('Genome', 'Whole genome',
    [qw( genome EnsEMBL::Web::Component::Location::Genome )],
    { 'availability' => 1 },
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
      marker EnsEMBL::Web::Component::Location::MarkerList
    )],
    { 'availability' => 'slice has_markers' }
  );

  $self->create_subnode(
    'Output', 'Export Location Data',
    [qw( export EnsEMBL::Web::Component::Export::Output )],
    { 'availability' => 'slice', 'no_menu_entry' => 1 }
  );
}

sub add_external_browsers {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $species_defs = $hub->species_defs;
  
  # Links to external browsers - UCSC, NCBI, etc
  my %browsers = %{$species_defs->EXTERNAL_GENOME_BROWSERS || {}};
  $browsers{'UCSC_DB'} = $species_defs->UCSC_GOLDEN_PATH;
  $browsers{'NCBI_DB'} = $species_defs->NCBI_GOLDEN_PATH;
  
  my ($chr, $start, $end) = $object ? ($object->seq_region_name, int $object->seq_region_start, int $object->seq_region_end) : ();
  my $url;
  
  if ($browsers{'UCSC_DB'}) {
    if ($chr) {
      $url = $hub->get_ExtURL('EGB_UCSC', { UCSC_DB => $browsers{'UCSC_DB'}, CHR => $chr, START => $start, END => $end });
    } else {
      $url = $hub->get_ExtURL('EGB_UCSC', { UCSC_DB => $browsers{'UCSC_DB'}, CHR => 1, START => 1, END => 1000000 });
    }
    
    $self->get_other_browsers_menu->append($self->create_node('UCSC_DB', 'UCSC', [], { availability => 1, url => $url, raw => 1, external => 1 }));
    
    delete $browsers{'UCSC_DB'};
  }
  
  if ($browsers{'NCBI_DB'}) {
    if ($chr) { 
      $url = $hub->get_ExtURL('EGB_NCBI', { NCBI_DB => $browsers{'NCBI_DB'}, CHR => $chr, START => $start, END => $end });
    } else {
      my $taxid = $species_defs->get_config($hub->species, 'TAXONOMY_ID'); 
      $url = "http://www.ncbi.nih.gov/mapview/map_search.cgi?taxid=$taxid";
    }
    
    $self->get_other_browsers_menu->append($self->create_node('NCBI_DB', 'NCBI', [], { availability => 1, url => $url, raw => 1, external => 1 }));
    
    delete $browsers{'NCBI_DB'};
  }

  $self->add_vega_link;
  
  foreach (sort keys %browsers) {
    next unless $browsers{$_};
    
    $url = $hub->get_ExtURL($_, { CHR => $chr, START => $start, END => $end });
    $self->get_other_browsers_menu->append($self->create_node($browsers{$_}, $browsers{$_}, [], { availability => 1, url => $url, raw => 1, external => 1 }));
  }
}

sub add_vega_link {
  my $self           = shift;
  my $hub            = $self->hub;
  my $urls           = $hub->ExtURL;
  my $species        = $hub->species;
  my $species_defs   = $hub->species_defs;
  my $type           = $hub->type;
  my $action         = $hub->action;
  my @alt_assemblies = @{$species_defs->ALTERNATIVE_ASSEMBLIES || []};
  my ($vega_link, $link_class);

  if (lc $species_defs->ENSEMBL_SITETYPE ne 'vega' && $action =~ /^(Chromosome|Overview|View)$/ && $alt_assemblies[0] =~ /VEGA/ && $urls->is_linked('VEGA')) {
    my $object = $self->object;
    
    if ($object) {
      my $reg        = 'Bio::EnsEMBL::Registry';
      my $orig_group = $reg->get_DNAAdaptor($species, 'vega')->group;
      
      $reg->add_DNAAdaptor($species, 'vega', $species, 'vega');
         
      my $chromosome   = $object->name;
      my $start        = $object->seq_region_start;
      my $end          = $object->seq_region_end;
      my $strand       = $object->seq_region_strand;
      my $coord_system = $object->slice->coord_system;
      my $start_slice  = $hub->get_adaptor('get_SliceAdaptor', 'vega')->fetch_by_region($coord_system->name, $chromosome, $start, $end, $strand, $coord_system->version);
      my $vega_projection;
      
      eval { $vega_projection = $start_slice->project($coord_system->name, $alt_assemblies[0]); };
      
      if ($vega_projection) {
        if (scalar @$vega_projection == 1) {
          my $vega_slice = $vega_projection->[0]->to_Slice;
          $vega_link  = $urls->get_url('VEGA', '') . "$species/$type/$action";
          $vega_link .= sprintf '?r=%s:%s-%s', map $vega_slice->$_, qw(seq_region_name start end);
        } elsif (scalar @$vega_projection > 1) {
          $vega_link  = $self->hub->url({ type => 'Help', action => 'ListVegaMappings' });
          $link_class = 'modal_link';
        }
      }
      
      $reg->add_DNAAdaptor($species, 'vega', $species, $orig_group); # set dnadb back to the original group
    }
    
    $self->get_other_browsers_menu->append($self->create_node('Vega', 'Vega', [], { availability => defined($vega_link), url => $vega_link, raw => 1, external => !defined($link_class), class => $link_class }));
  }
}

sub get_other_browsers_menu {
  my $self = shift;
  # The menu may already have an other browsers sub menu from Ensembl, if so we add to this one, otherwise create it
  return $self->{'browser_menu'} ||= $self->get_submenu('OtherBrowsers') || $self->create_submenu('OtherBrowsers', 'Other genome browsers');
}

1;
