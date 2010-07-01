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

sub populate_tree {
  my $self = shift;
  my $object = $self->object;
  
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

  $self->add_external_browsers;
}

sub add_external_browsers {
  my $self = shift;
  my $object = $self->object;
  
  
  # Links to external browsers - UCSC, NCBI, etc
  my %browsers = %{$object->species_defs->EXTERNAL_GENOME_BROWSERS || {}};
  $browsers{'UCSC_DB'} = $object->species_defs->UCSC_GOLDEN_PATH;
  $browsers{'NCBI_DB'} = $object->species_defs->NCBI_GOLDEN_PATH;
  
  my $url;
  
  if ($browsers{'UCSC_DB'}) {
    if ($object->seq_region_name) {
      $url = $object->get_ExtURL('EGB_UCSC', { 'UCSC_DB' => $browsers{'UCSC_DB'}, 'CHR' => $object->seq_region_name, 'START' => int($object->seq_region_start), 'END' => int($object->seq_region_end) });
    } else {
      $url = $object->get_ExtURL('EGB_UCSC', { 'UCSC_DB' => $browsers{'UCSC_DB'}, 'CHR' => '1', 'START' => '1', 'END' => '1000000' });
    }
    
    $self->get_other_browsers_menu->append($self->create_node('UCSC_DB', 'UCSC', [], { 'availability' => 1, 'url' => $url, 'raw' => 1, 'external' => 1 }));
    
    delete($browsers{'UCSC_DB'});
  }
  
  if ($browsers{'NCBI_DB'}) {
    if ($object->seq_region_name) { 
      $url = $object->get_ExtURL('EGB_NCBI', { 'NCBI_DB' => $browsers{'NCBI_DB'}, 'CHR' => $object->seq_region_name, 'START' => int($object->seq_region_start), 'END' => int($object->seq_region_end) });
    } else {
      my $taxid = $object->species_defs->get_config($object->species, 'TAXONOMY_ID'); 
      $url = "http://www.ncbi.nih.gov/mapview/map_search.cgi?taxid=$taxid";
    }
    
    $self->get_other_browsers_menu->append($self->create_node('NCBI_DB', 'NCBI', [], { 'availability' => 1, 'url' => $url, 'raw' => 1, 'external' => 1 }));
    
    delete($browsers{'NCBI_DB'});
  }

  $self->add_vega_link;  
  foreach (sort keys %browsers) {
    next unless $browsers{$_};
    
    $url = $object->get_ExtURL($_, { 'CHR' => $object->seq_region_name, 'START' => int($object->seq_region_start), 'END' => int($object->seq_region_end) });
    $self->get_other_browsers_menu->append($self->create_node($browsers{$_}, $browsers{$_}, [], { 'availability' => 1, 'url' => $url, 'raw' => 1, 'external' => 1 }));
  }
}

sub add_vega_link {
  my $self = shift;
  my $object = $self->object;
  my $vega_link='';
  my $urls = $object->ExtURL;
  my $species=$object->species;
  my $alt_assemblies;
  my $link_class='';

  if(defined($object) && (lc $object->species_defs->ENSEMBL_SITETYPE) ne 'vega' && $object->type eq 'Location' ##For the location page (if the site s not a vega website), add the Vega menu entry in other browsers menu
    && ($alt_assemblies= $object->hub->species_defs->ALTERNATIVE_ASSEMBLIES)){ ##check we have alternate assemblies  
    if( ($object->action eq "Chromosome" || $object->action eq "Overview" || $object->action eq "View") ##The link is only enabled for Chromosome, overview and View actions
      && (scalar(@$alt_assemblies)!=0) && (@$alt_assemblies[0]=~ /VEGA/) && $urls && $urls->is_linked("VEGA")){ ## retreive the vega (base-) url
      ## set dnadb to 'vega' so that the assembly mapping is retrieved from there		 
      my $chromosome= $object->name;		   
      my $reg = "Bio::EnsEMBL::Registry";
      my $vega_dnadb = $reg->get_DNAAdaptor($species, 'vega');
      $reg->add_DNAAdaptor($species, "vega", $species, 'vega');
      ## get a Vega slice to do the projection
      my $vega_sa = Bio::EnsEMBL::Registry->get_adaptor($species, 'vega', "Slice");
      my $start_location = $object->hub->core_objects->location->start;
      my $end_location = $object->hub->core_objects->location->end;

      my $my_slice = $object->Obj->{"slice"};
      my $coordinate_system=$my_slice->coord_system;
      my $strand=$my_slice->strand;

      my $start_slice = $vega_sa->fetch_by_region( $coordinate_system->name, $chromosome,$start_location,$end_location,$strand,$coordinate_system->version );
	  my $start_V_projection= undef;
	  eval{
        $start_V_projection = $start_slice->project($coordinate_system->name, @$alt_assemblies[0]) or die "print($coordinate_system->name): $!";
	  };
      if(defined($start_V_projection)){
        if(scalar(@$start_V_projection) ==1){
          $vega_link = $urls->get_url("VEGA", "") . $species."/".$object->type."/".$object->action;
          $vega_link.= "?r=".@$start_V_projection[0]->to_Slice->seq_region_name.":".@$start_V_projection[0]->to_Slice->start."-".@$start_V_projection[0]->to_Slice->end;                                      
        }elsif(scalar(@$start_V_projection) > 1){
          $vega_link="../Help/ListVegaMappings?type=".$object->type.";action=".$object->action.";"; #explicitly pass the type and action, as this is used in ListVegaMappings, to form the links to Vega        
          my $parameters=$object->hub->core_objects->{'parameters'}; #add url parameters, so the list can get its location
          while ((my $key, my $value) = each (%$parameters)){
            $vega_link.=$key."=".$value.";";
          }
          $vega_link.="species=".$species;
          $link_class='modal_link';
        }
	  }
    }
    $self->get_other_browsers_menu->append($self->create_node('Vega', 'Vega' , [], { 'availability' => ($vega_link ne ''), 'url' => $vega_link, 'raw' => 1, 'external' => ($link_class eq '') , class=>$link_class }));      
  }
}

sub get_other_browsers_menu{
   my $self=shift;
  #The menu may already have an other browsers sub menu from Ensembl, if so we add to this one, otherwise create it
  if(!defined($self->{browser_menu})){
    if(! $self->get_submenu('OtherBrowsers')){
      $self->{browser_menu} = $self->create_submenu('OtherBrowsers', 'Other genome browsers');
    }
  }
  return $self->{browser_menu};
}
1;
