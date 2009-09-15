package EnsEMBL::Web::Configuration::Location;

use strict;

use base qw( EnsEMBL::Web::Configuration );

use CGI;

use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::Component::Location;

sub set_default_action {
  my $self = shift;
  unless( ref $self->object ) {
    $self->{_data}{default} = 'Genome';
    return;
  }
  my $x = $self->object->availability || {};
  if( $x->{'slice'} ) {
    $self->{_data}{default} = 'View';
  } elsif( $x->{'chromosome'} ) {
    $self->{_data}{default} = 'Chromosome';
  } else {
    $self->{_data}{default} = 'Genome';
  }
}

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;    }
sub content_panel  { return $_[0]->_content_panel;  }
sub configurator   { return $_[0]->_configurator;   }
sub context_panel  { return $_[0]->_context_panel;  }

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


sub extra_populate_tree {
  my $self = shift;
  my $object = $self->object;
  my $availability = $object->availability;
  
  ## Links to external browsers - UCSC, NCBI, etc
  my %browsers = %{$object->species_defs->EXTERNAL_GENOME_BROWSERS || {}};
  $browsers{'UCSC_DB'} = $object->species_defs->UCSC_GOLDEN_PATH;
  $browsers{'NCBI_DB'} = $object->species_defs->NCBI_GOLDEN_PATH;
  my $url;
  my $browser_menu = $self->create_submenu('OtherBrowsers', 'Other genome browsers');
  if ($browsers{'UCSC_DB'}) {
    if ($object->seq_region_name) {
      $url = $object->get_ExtURL( 'EGB_UCSC', { 'UCSC_DB' => $browsers{'UCSC_DB'}, 'CHR' => $object->seq_region_name, 'START' => int( $object->seq_region_start ), 'END' => int( $object->seq_region_end )} );
    }
    else {
      $url = $object->get_ExtURL( 'EGB_UCSC', { 'UCSC_DB' => $browsers{'UCSC_DB'}, 'CHR' => '1', 'START' => '1', 'END' => '1000000'} );
    }
    $browser_menu->append( $self->create_node('UCSC_DB', 'UCSC',
      [], { 'availability' => 1, 'url' => $url, 'raw' => 1, 'external' => 1 }
    ));
    delete($browsers{'UCSC_DB'});
  }
  if ($browsers{'NCBI_DB'}) {
    if ($object->seq_region_name) { 
      $url = $object->get_ExtURL('EGB_NCBI', { 'NCBI_DB' => $browsers{'NCBI_DB'}, 'CHR' => $object->seq_region_name, 'START' => int( $object->seq_region_start ), 'END' => int( $object->seq_region_end )} );
    }
    else {
      my $taxid = $object->species_defs->get_config($object->species, 'TAXONOMY_ID'); 
      $url = 'http://www.ncbi.nih.gov/mapview/map_search.cgi?taxid='.$taxid;
    }
    $browser_menu->append( $self->create_node('NCBI_DB', 'NCBI',
      [], { 'availability' => 1, 'url' => $url, 'raw' => 1, 'external' => 1 }
    ));
    delete($browsers{'NCBI_DB'});
  }
  foreach (sort keys %browsers) {
    next unless $browsers{$_};
    $url = $object->get_ExtURL( $_, {'CHR' => $object->seq_region_name, 'START' => int( $object->seq_region_start ), 'END' => int( $object->seq_region_end ) } );
    $browser_menu->append($self->create_node($browsers{$_}, $browsers{$_},
      [], { 'availability' => 1, 'url' => $url, 'raw' => 1, 'external' => 1 }
    ));
  }
}

sub populate_tree {
  my $self = shift;
  my $object = $self->object;
  my $availability = $object->availability;
  my $caption;
  
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
  
  $caption = $availability->{'slice'} ? 'Alignments (image) ([[counts::alignments]])' : 'Alignments (image)';
  
  $align_menu->append($self->create_node('Align', $caption, 
    [qw(
      top      EnsEMBL::Web::Component::Location::ViewTop
      selector EnsEMBL::Web::Component::Compara_AlignSliceSelector
      botnav   EnsEMBL::Web::Component::Location::ViewBottomNav
      bottom   EnsEMBL::Web::Component::Location::Compara_AlignSliceBottom
    )],
    { 'availability' => 'slice database:compara', 'concise' => 'Alignments (image)' }
  ));
  
  $caption = $availability->{'slice'} ? 'Alignments (text) ([[counts::alignments]])' : 'Alignments (text)';
  
  $align_menu->append($self->create_node('Compara_Alignments', $caption,
    [qw(
      selector   EnsEMBL::Web::Component::Compara_AlignSliceSelector
      botnav     EnsEMBL::Web::Component::Location::ViewBottomNav
      alignments EnsEMBL::Web::Component::Location::Compara_Alignments
    )],
    { 'availability' => 'slice database:compara', 'concise' => 'Alignments (text)' }
  ));
  
  $caption = $availability->{'slice'} ? 'Multi-species view ([[counts::pairwise_alignments]])' : 'Multi-species view';
  
  $align_menu->append($self->create_node('Multi', $caption,
    [qw(
      selector EnsEMBL::Web::Component::Location::SelectAlignment
      top      EnsEMBL::Web::Component::Location::MultiTop
      botnav   EnsEMBL::Web::Component::Location::ViewBottomNav
      bottom   EnsEMBL::Web::Component::Location::MultiBottom
    )],
    { 'availability' => 'slice database:compara', 'concise' => 'Multi-species view' }
  ));
  
  $align_menu->append($self->create_subnode('ComparaGenomicAlignment', '',
    [qw( gen_alignment EnsEMBL::Web::Component::Location::ComparaGenomicAlignment )],
    { 'no_menu_entry' => 1 }
  ));
  
  $caption = $availability->{'chromosome'} ? 'Synteny ([[counts::synteny]])' : 'Synteny';
  
  $align_menu->append($self->create_node('Synteny', $caption,
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
  
  $caption = $availability->{'slice'} ? 'Resequencing ([[counts::reseq_strains]])' : 'Resequencing';
  
  $variation_menu->append($self->create_node('SequenceAlignment', $caption,
    [qw(
      botnav EnsEMBL::Web::Component::Location::ViewBottomNav
            align  EnsEMBL::Web::Component::Location::SequenceAlignment
    )],
    { 'availability' => 'slice has_strains', 'concise' => 'Resequencing Alignments' }
  ));
  $variation_menu->append($self->create_node('LD', 'Linkage Data',
    [qw(
      ld      EnsEMBL::Web::Component::Location::LD
      ldimage EnsEMBL::Web::Component::Location::LDImage
    )],
    { 'availability' => 'slice has_LD', 'concise' => 'Linkage Disequilibrium Data' }
  ));

  $self->create_node('Marker', 'Markers',
    [qw(
      botnav EnsEMBL::Web::Component::Location::ViewBottomNav
      marker EnsEMBL::Web::Component::Location::MarkerDetails
    )],
    { 'availability' => 'slice has_markers' }
  );

  $self->create_subnode(
    'Export', '',
    [qw( export EnsEMBL::Web::Component::Export::Location )],
    { 'availability' => 'slice', 'no_menu_entry' => 1 }
  );
}

sub ajax_zmenu {
  my $self = shift;

  my $obj = $self->object;

  my $action = $obj->[1]{'_action'} || 'Summary';

  if( $action =~ /Regulation/){
    return $self->ajax_zmenu_regulation;
  } elsif( $action =~/RegFeature/){
    return $self->ajax_zmenu_reg_feature; 
  } elsif ($action =~ /Variation/) {
    return $self->ajax_zmenu_variation;
  } elsif ($action =~ /Genome/) {
    return $self->_ajax_zmenu_alignment;
  } elsif ($action =~ /Marker/) {
    return $self->_ajax_zmenu_marker;
  } elsif ($action eq 'ComparaGenomicAlignment') {
    return $self->_ajax_zmenu_ga;
  } elsif ($action eq 'Compara_Alignments') {
    return $self->_ajax_zmenu_av;
  } elsif ($action =~ /View|Overview/) {
    return $self->_ajax_zmenu_view;
  } elsif ($action eq 'coverage') {
    return $self->ajax_zmenu_read_coverage;
  } elsif ($action =~ /Supercontigs/) {
    return $self->_ajax_zmenu_supercontig;
  } elsif ($action eq 'Das') {
    return $self->_ajax_zmenu_das;
  } elsif ($action eq 'Align') {
    return $self->_ajax_zmenu_alignslice;
  }
}

sub _ajax_zmenu_view {
  my $self  = shift;
  
  my $panel = $self->_ajax_zmenu;
  my $obj   = $self->object;
  
  if ($obj->param('mfid')) {
    return $self->_ajax_zmenu_misc_feature($panel,$obj);
  } elsif ($obj->param('region_n')) {
    return $self->_ajax_zmenu_region($panel,$obj);
  } elsif ($obj->param('r1') || $obj->param('ori')) {
    return $self->_ajax_zmenu_synteny($panel,$obj);
  } else {
    # otherwise simply show a link to View/Overview
    my $r             = $obj->param('r');
    my ($chr, $loc)   = split ':', $r;
    my ($start,$stop) = split '-', $loc;
    my $action        = $obj->[1]{'_action'} || 'View';
    my $threshold     = 1000100 * ($obj->species_defs->ENSEMBL_GENOME_SIZE||1);

    # go to Overview if region too large for View
    $action = 'Overview' if (($stop-$start+1 > $threshold) && $action eq 'View');
    my $url = $obj->_url({
      'type' => 'Location',
      'action' => $action
    });
   
    my $caption = $r;
    my $link_title = $r;

    # code for alternative assembly zmenu
    if ($obj->param('assembly')) {
      my $this_assembly = $obj->species_defs->ASSEMBLY_NAME;
      my $alt_assembly  = $obj->param('assembly');
      $caption = $alt_assembly.':'.$r;

      # choose where to jump to
      if ($this_assembly eq 'VEGA') {
        $url = sprintf("%s%s/%s/%s?r=%s", $self->object->species_defs->ENSEMBL_EXTERNAL_URLS->{'ENSEMBL'}, $obj->[1]{'_species'}, 'Location', $action, $r);
        $link_title = 'Jump to Ensembl';
      } elsif ($alt_assembly eq 'VEGA') {
        $url = sprintf("%s%s/%s/%s?r=%s", $self->object->species_defs->ENSEMBL_EXTERNAL_URLS->{'VEGA'}   , $obj->[1]{'_species'}, 'Location', $action, $r);
        $link_title = 'Jump to VEGA';
      } else {
        # TODO: put URL to the latest archive site showing the other assembly (from mapping_session table)
      }
      $panel->add_entry({ 'label' => 'Assembly: '.$alt_assembly, 'priority' => 100});

    } elsif (my $loc = $obj->param('jump_loc')) { # code for alternative clones zmenu
      ($caption) = split ':', $loc;
      my $status = $obj->param('status');
      if ( $obj->species_defs->ASSEMBLY_NAME eq 'VEGA') {
        $link_title = 'Jump to Ensembl';
        $url = sprintf("%s%s/%s/%s?r=%s", $obj->species_defs->ENSEMBL_EXTERNAL_URLS->{'ENSEMBL'}, $obj->[1]{'_species'}, 'Location', $action, $loc);
      }
      else {
        $link_title = 'Jump to Vega';
        $url = sprintf("%s%s/%s/%s?r=%s", $obj->species_defs->ENSEMBL_EXTERNAL_URLS->{'VEGA'}   , $obj->[1]{'_species'}, 'Location', $action, $loc);
      }
      $status =~ s/_clone/ version/g;
      $panel->add_entry({ 'label' => 'Status: '.$status, 'priority' => 100});
    }
    
    $panel->{'caption'} = $caption;
    $panel->add_entry({ 'label' => $link_title, 'link' => $url, 'priority' => 50 });
  }
}

sub _ajax_zmenu_supercontig {
  my $self  = shift;
  
  my $panel = $self->_ajax_zmenu;
  my $obj   = $self->object;

  $panel->{'caption'} = $obj->param('ctg') ." " . $obj->param('r');
  my $url = $obj->_url({
    'type'      => 'Location',
    'action'    => 'Overview',
    'r'         => $obj->param('r'),
    'cytoview'  => 'misc_feature_core_superctgs=normal'
  });
  $panel->add_entry({'label' => 'Jump to Supercontig', 'link' => $url});
  return;
}

sub _ajax_zmenu_synteny {
  my $self = shift;
  my $panel= shift;
  my $obj  = shift; 
  my $action = $obj->[1]{'_action'};
  my $sp     = $obj->[1]{'_species'};
  my $ori    = $obj->param('ori');
  my $r      = $obj->param('r');
  my ($chr, $loc)   = split ':', $r;
  my ($start,$stop) = split '-', $loc;
  my $url = $obj->_url({
    'type'   => 'Location',
    'action' => $action,
    'r' => $r });
  $panel->{'caption'} = "$sp $chr:$loc";
  if (my $r1  = $obj->param('r1')) {
    my $sp1 = $obj->param('sp1');
    $panel->add_entry({
      'label'   => sprintf("%s Chr %s:%0.1fM-%0.1fM",$sp,$chr,$start/1e6,$stop/1e6),
      'link'    => $url,
      'priority'=> 100,
    });
    my ($chr1, $loc1)   = split ':', $r1;
    my ($start1,$stop1) = split '-', $loc1;
    my $url1 = $obj->_url({
      'type' => 'Location',
      'action' => $action,
      'r' => $r1,
      'species' => $sp1 });
    $panel->add_entry({
      'label'   => sprintf("%s Chr %s:%0.1fM-%0.1fM",$sp1,$chr1,$start1/1e6,$stop1/1e6),
      'link'    => $url1,
      'priority'=> 90,
    });
    my $new_start = int(($stop+$start)/2) - 5e5;
    my $new_end   = $new_start + 1e6 - 1;
    my $synt_url  = $obj->_url({
      'type'         => 'Location',
      'action'       => 'Synteny',
      'otherspecies' => $sp1,
      'r'            => "$chr:$new_start-$new_end"});
    if (my $ori = $obj->param('ori')) {
      $panel->add_entry({
        'label'   => 'Center display on this chr',
        'link'    => $synt_url,
        'priority'=> 80,
      });
      $panel->add_entry({
        'label'   => "Orientation: $ori",
        'priority'=> 70,
      });
    }
    else {
      $panel->add_entry({
        'label'   => 'Center gene list',
        'link'    => $synt_url,
        'priority'=> 80,
      });
    }
  }
  else {
    my ($chr, $loc) = split ':', $r;
    my $url = $obj->_url({
      'type' => 'Location',
      'action' => $action,
      'r' => $r});
    $panel->add_entry({
      'label'    => "Jump to $sp",
      'link'    => $url,
      'priority'=> 100,
    });
    $panel->add_entry({
      'label'    => "bp: $loc",
      'priority'=> 90,
    });
    $panel->add_entry({
      'label'    => "orientation: $ori",
      'priority'=> 80,
    });
  }
  return;
}

sub _ajax_zmenu_region {
  my $self = shift;
  my $panel= shift;
  my $obj  = shift;
  my $threshold   = 1000100 * ($obj->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $action     = $obj->[1]{'_action'};
  my $slice_name = $obj->param('region_n');
  my $db_adaptor = $obj->database('core');
  my $sa         = $db_adaptor->get_SliceAdaptor();
  my $slice      = $sa->fetch_by_region('seqlevel',$slice_name);
  my $slice_type = $slice->coord_system_name;
  my $top_level_proj  = $slice->project('toplevel');
  my $top_level_slice = $top_level_proj->[0]->to_Slice;
  my $top_level_name  = $top_level_slice->seq_region_name;
  my $top_level_start = $top_level_slice->start;
  my $top_level_end   = $top_level_slice->end;
  my $new_r = "$top_level_name:$top_level_start-$top_level_end";
  my $priority = 200;
  $panel->{'caption'} = $slice_name;
  my $url = $obj->_url({'type'=>'Location','action'=>$action,'region'=>$slice_name,});
  $priority--;
  $panel->add_entry({
    'label'     => "Center on $slice_type $slice_name",
    'link'     => $url,
    'priority' => $priority,
  });
#  my $referer = $obj->_url({'type'=>'Location','action'=>"$action",'r'=>undef,'region'=>$slice_name}); # doesn't seem to be needed
  my $export_URL = $obj->_url({'type'=>'Export','action'=>"Location/$action",'r'=>$new_r});
  $priority--;
  $panel->add_entry({
    'label'    => "Export $slice_type sequence/features",
    'link'    => $export_URL,
    'priority'=> $priority,
    'class'   => 'modal_link',
  });
  foreach my $cs (@{$db_adaptor->get_CoordSystemAdaptor->fetch_all() || []}) {
    $priority--;
    next if $cs->name eq $slice_type; #don't show the slice coord system twice
    next if $cs->name eq 'chromosome'; #don't allow breaking of site by exporting all chromosome features
    my $path;
    eval { $path = $slice->project($cs->name); };
    next unless $path;
    next unless(@$path == 1);

    my $new_slice = $path->[0]->to_Slice->seq_region_Slice;
    my $new_slice_type = $new_slice->coord_system_name();
    my $new_slice_name = $new_slice->seq_region_name();
    my $new_slice_length = $new_slice->seq_region_length();

    $action = $new_slice_length > $threshold ? 'Overview' : 'View';
    my $new_slice_URL = $obj->_url({'type'=>'Location','action'=>$action,'region'=>$new_slice_name});
    $priority--;
    $panel->add_entry({
      'label'    => "Center on $new_slice_type $new_slice_name",
      'link'    => $new_slice_URL,
      'priority'=> $priority,
    });

    # would be nice if exportview could work with the region parameter, either in the referer or in the real URL
    # since it doesn't we have to explicitly calculate the locations of all regions on top level
    my $top_level_proj  = $new_slice->project('toplevel');
    my $top_level_slice = $top_level_proj->[0]->to_Slice;
    my $top_level_name  = $top_level_slice->seq_region_name;
    my $top_level_start = $top_level_slice->start;
    my $top_level_end = $top_level_slice->end;
    my $new_r = "$top_level_name:$top_level_start-$top_level_end";

    $export_URL = $obj->_url({'type'=>'Export','action' =>"Location/$action",'r'=>$new_r});

    $priority--;
    $panel->add_entry({
      'label'    => "Export $new_slice_type sequence/features",
      'link'    => $export_URL,
      'priority'=> $priority,
      'class'   => 'modal_link',
    });
    if ($cs->name eq 'clone') {
      (my $short_name = $new_slice_name) =~ s/\.\d+$//;
      $priority--;
      $panel->add_entry({
        'type'     => 'EMBL',
        'label'    => $new_slice_name,
        'link'     => $obj->get_ExtURL('EMBL', $new_slice_name),
        'priority' => $priority,
        'extra'    => { external => 1 }
      });
      $priority--;
      $panel->add_entry({
        'type'     => 'EMBL (latest version)',
        'label'    => $short_name,
        'link'     => $obj->get_ExtURL('EMBL', $short_name),
        'priority' => $priority,
        'extra'    => { external => 1 }
      });
    }
  }
}

sub _ajax_zmenu_misc_feature {
  my $self = shift;
  my $panel= shift;
  my $obj  = shift;
  my $name = $obj->param('misc_feature_n');
  my $id   = $obj->param('mfid');
  my $url  = $obj->_url({'type' => 'Location', 'action' => 'View', 'misc_feature' => $name});
  my $db         = $obj->param('db')  || 'core';
  my $db_adaptor = $obj->database(lc($db));
  my $mfa        = $db_adaptor->get_MiscFeatureAdaptor();
  my $mf         = $mfa->fetch_by_dbID($id);
  my $type       = $mf->get_all_MiscSets->[0]->code;
  my $caption = $type eq 'encode' ? 'Encode region'
    : $type eq 'ntctgs' ? 'NT Contig'
      : 'Clone';
  $panel->{'caption'} = "$caption: $name";

  $panel->add_entry({
    'type' => 'bp',
    'label' => $mf->seq_region_start.'-'.$mf->seq_region_end,
    'priority' => 190,
  });

  $panel->add_entry({
    'type' => 'length',
    'label' => $mf->length.' bps',
    'priority' => 180,
  });

  # add entries for each of the following attributes
  my @names = ( 
    ['name',           'Name'                   ],
    ['well_name',      'Well name'              ],
    ['sanger_project', 'Sanger project'         ],
    ['clone_name',     'Library name'           ],
    ['synonym',        'Synonym'                ],
    ['embl_acc',       'EMBL accession', 'EMBL' ],
    ['bacend',         'BAC end acc',    'EMBL' ],
    ['bac',            'AGP clones'             ],
    ['alt_well_name',  'Well name'              ],
    ['bacend_well_nam','BAC end well'           ],
    ['state',          'State'                  ],
    ['htg',            'HTGS_phase'             ],
    ['remark',         'Remark'                 ],
    ['organisation',   'Organisation'           ],
    ['seq_len',        'Seq length'             ],
    ['fp_size',        'FP length'              ],
    ['supercontig',    'Super contig'           ],
    ['fish',           'FISH'                   ],
    ['description',    'Description'            ],
  );

  my $priority = 170;
  foreach my $name (@names) {
    my $value = $mf->get_scalar_attribute($name->[0]);
    my $entry;

    # hacks for these type of entries
    if ($name->[0] eq 'BACend_flag') {
      $value = ('Interpolated', 'Start located', 'End located', 'Both ends located') [$value]; 
    }
    if ($name->[0] eq 'synonym') {
      $value = "http://www.sanger.ac.uk/cgi-bin/humace/clone_status?clone_name=$value" if $mf->get_scalar_attribute('organisation') eq 'SC';
    }
    if ($value) {
      $entry = {
        'type'     => $name->[1],
        'label'    => $value,
        'priority' => $priority,};
      if ($name->[2]) {
        $entry->{'link'} = $obj->get_ExtURL($name->[2],$value);
      }
      $panel->add_entry($entry);
      $priority--;
    }
  }

  $panel->add_entry({
    'label' => "Center on $caption",
    'link'   => $url,
    'priority' => $priority,
  });

  # this is all for pre so can be sorted for that when the time comes
  # my $links = $self->my_config('LINKS');
  # if( $links ) {
  #   my $Z = 80;
  #   foreach ( @$links ) {
  #     my $val = $f->get_scalar_attribute($_->[1]);
  #     next unless $val;
  #     (my $href = $_->[2]) =~ s/###ID###/$val/g;
  #     $zmenu->{"$Z:$_->[0]: $val"} = $href;
  #     $Z++;
  #   }
  # }

}

sub _ajax_zmenu_av {
  my $self = shift;
  
  my $panel = $self->_ajax_zmenu;
  my $obj = $self->object;
  my $id = $obj->param('id');
  my $obj_type  = $obj->param('ftype');
  my $align = $obj->param('align');
  my $hash = $obj->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'};
  my $caption = $hash->{$align}{'name'};
  my $url = $obj->_url({ 'type' => 'Location', 'action' => 'Compara_Alignments', 'align' => $align });

  my ($chr, $start, $end) = split(/[\:\-]/, $obj->param('r'));
  
  # if there's a score than show it and also change the name of the track (hacky)
  if ($obj_type && $id) {
    my $db_adaptor   = $obj->database('compara');
    my $adaptor_name = "get_${obj_type}Adaptor";
    my $feat_adap =  $db_adaptor->$adaptor_name;
    my $feature = $feat_adap->fetch_by_dbID($id);
    
    if ($obj_type eq 'ConstrainedElement') {
      if ($feature->p_value) {
        $panel->add_entry({
          'type'     => 'p-value',
          'label'    => sprintf("%.2e", $feature->p_value),
          'priority' => 107
        });
      }
      
      $panel->add_entry({
        'type'  => 'Score',
        'label' => sprintf("%.2f", $feature->score),
        'priority' => 106,
      });
      if ($caption =~ /^(\d+)/) {
        $caption = "Constrained el. $1 way";
      }
    } elsif ($obj_type eq "GenomicAlignBlock" and $obj->param('ref_id')) {
      $feature->{reference_genomic_align_id} = $obj->param('ref_id');
      $start = $feature->reference_genomic_align->dnafrag_start;
      $end = $feature->{reference_genomic_align}->dnafrag_end;
    }
  }
  $panel->add_entry({
    'type'  => 'start',
    'label' => $start,
    'priority' => 110,
  });
  $panel->add_entry({
    'type'  => 'end',
    'label' => $end,
    'priority' => 109,
  });
  $panel->add_entry({
    'type'  => 'length',
    'label' => ($end-$start+1). " bp",
    'priority' => 108,
  });
  $panel->{'caption'} = $caption;
  $panel->add_entry({
    'label' => 'View alignments',
    'link'  => $url,
    'priority' => 100, # default
  });
  return;
}

sub _ajax_zmenu_ga {
  my $self   = shift;
  
  my $panel  = $self->_ajax_zmenu;
  my $obj    = $self->object;
  my $sp1    = $obj->param('s1');
  my $orient = $obj->param('orient');
  my $disp_method = $obj->param('method');
  $disp_method =~ s/BLASTZ_NET/BLASTz net/g;
  $disp_method =~ s/TRANSLATED_BLAT_NET/Trans. BLAT net/g;
  $panel->{'caption'} = "$sp1 $disp_method";

  my $r1 = $obj->param('r1');
  $panel->add_entry({
    'type'     => $r1,
    'priority' => 250,
  });
  $panel->add_entry({
    'type'     => 'Orientation',
    'label'    => $orient,
    'priority' => 200,
  });
  my $url = $obj->_url({
    'type'    => 'Location',
    'action'  => 'View',
    'species' => $sp1,
    'r'       => $r1
  });
  $panel->add_entry({
    'label'    => "Jump to $sp1",
    'link'     => $url,
    'priority' => 150,
  });

  if ($obj->param('method')) {
    $url = $obj->_url({
      'type'  =>'Location',
      'action'=>'ComparaGenomicAlignment',
      's1'    =>$sp1,
      'r1'    =>$obj->param('r1'),
      'method'=>$obj->param('method')
     });
    $panel->add_entry({
      'label'    => 'View alignment',
      'link'     => $url,
      'priority' => 100,
    });

    $url = $obj->_url({
      'type'  =>'Location',
      'action'=>'View',
      'r'     =>$obj->param('r')
    });
    $panel->add_entry({
      'label'    => 'Center on this location',
      'link'     => $url,
      'priority' => 50,
    });
  }
  return;
}

sub _ajax_zmenu_marker {
  my $self = shift;
  
  my $panel   = $self->_ajax_zmenu;
  my $obj     = $self->object;
  my $caption = $obj->param('m');
  
  $panel->{'caption'} = $caption;
  my $url = $obj->_url({'type'=>'Location','action'=>'Marker','m'=>$caption});
  $panel->add_entry({
    'label' => 'Marker info.',
    'link'  => $url,
  });
  return;
}


# zmenu for aligments (directed to /Location/Genome)
sub _ajax_zmenu_alignment {
  my $self = shift;
  
  my $panel     = $self->_ajax_zmenu;
  my $obj       = $self->object;
  my $id        = $obj->param('id');
  my $obj_type  = $obj->param('ftype');
  my $db        = $obj->param('fdb') || $obj->param('db') || 'core'; 

  my $db_adaptor = $obj->database(lc($db));
  my $adaptor_name = "get_${obj_type}Adaptor";
  my $feat_adap =  $db_adaptor->$adaptor_name; 
  my $fs =[]; 
  unless ( $obj->param('ptype') eq 'probe' ){
    $fs = $feat_adap->can( 'fetch_all_by_hit_name' ) ? $feat_adap->fetch_all_by_hit_name($id)
      : $feat_adap->can( 'fetch_all_by_probeset' ) ? $feat_adap->fetch_all_by_probeset($id)
      :                                              []
      ;

  } 

  if ( @$fs ==0  && $feat_adap->can( 'fetch_all_by_Probe' ) ){
    my $probe_adap = $db_adaptor->get_ProbeAdaptor;
    my $probe_obj = $probe_adap->fetch_by_array_probe_probeset_name($obj->param('array'), $id);
    $fs = $feat_adap->fetch_all_by_Probe($probe_obj);
    $panel->{'caption'} = "Probe: $id";
  }
  my $external_db_id = ($fs->[0] && $fs->[0]->can('external_db_id')) ? $fs->[0]->external_db_id : '';
  my $extdbs = $external_db_id ? $obj->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'external_db'}{'entries'} : {};
  my $hit_db_name = $extdbs->{$external_db_id}{'db_name'} || 'External Feature';
  # hack to link sheep bac ends to trace archive
  if ($fs->[0]->analysis->logic_name =~ /sheep_bac_ends|BACends/) {
    $hit_db_name = 'TRACE';
  }

  my $species= $obj->species;

  # different zmenu for oligofeatures
  if ($obj_type eq 'ProbeFeature') {
    my $array_name = $obj->param('array') || '';
    my $ptype = $obj->param('ptype') || '';
    unless ($panel->{'caption'}) { $panel->{'caption'} = "Probe set: $id"; }
    my $fv_url = $obj->_url({'type'=>'Location','action'=>'Genome','ftype'=>$obj_type,'id'=>$id,'fdb'=>'funcgen', 'ptype'=>$ptype, 'db' =>'core'});
    my $p = 50;
    $panel->add_entry({ 
      'label' => 'View all probe hits',
      'link'   => $fv_url,
      'priority' => $p,
    });

    # details of each probe within the probe set on the array that are found within the slice
    my ($r_name,$r_start,$r_end) = $obj->param('r') =~ /(\w+):(\d+)-(\d+)/;
    my %probes;

    foreach my $of (@$fs){ 
      my $op = $of->probe; 
      my $of_name    = $of->probe->get_probename($array_name);
      my $of_sr_name = $of->seq_region_name;
      next if ("$of_sr_name" ne "$r_name");
      my $of_start   = $of->seq_region_start;
      my $of_end     = $of->seq_region_end;
      next if ( ($of_start > $r_end) || ($of_end < $r_start));
      my $loc = $of_start.'bp-'.$of_end.'bp';
      $probes{$of_name}{'chr'}   = $of_sr_name;
      $probes{$of_name}{'start'} = $of_start;
      $probes{$of_name}{'end'}   = $of_end;
      $probes{$of_name}{'loc'}   = $loc;
    }
    foreach my $probe (sort {
      $probes{$a}->{'chr'}   <=> $probes{$b}->{'chr'}
   || $probes{$a}->{'start'} <=> $probes{$b}->{'start'}
   || $probes{$a}->{'stop'}  <=> $probes{$b}->{'stop'}
      } keys %probes) {
      my $type = $p < 50 ? ' ' : 'Individual probes:';
      $p--;
      my $loc = $probes{$probe}->{'loc'};
      $panel->add_entry({
        'type'     => $type,
        'label'    => "$probe ($loc)",
        'priority' => $p,
      });
    }
  } else {
    $panel->{'caption'} = "$id ($hit_db_name)";
    my @seq = [];
    @seq = split "\n", $obj->get_ext_seq($id,$hit_db_name) if ($hit_db_name !~ /CCDS/); #don't show EMBL desc for CCDS
    my $desc = $seq[0];
    if ($desc) {
      if ($desc =~ s/^>//) {
        $panel->add_entry({
          'label' => $desc,
          'priority' => 150,
        });
      }
    }
    my $URL = CGI::escapeHTML( $obj->get_ExtURL($hit_db_name, $id) );
    my $label = ($hit_db_name eq 'TRACE') ? 'View Trace archive' : $id;
    $panel->add_entry({
      'label' => $label,
      'link'  => $URL,
      'priority' => 100,
    });
    my $fv_url = $obj->_url({'type'=>'Location','action'=>'Genome','ftype'=>$obj_type,'id'=>$id,'db'=>$db});
    $panel->add_entry({ 
      'label' => "View all hits",
      'link'   => $fv_url,
      'priority' => 50,
    });
  }
  return;
}

sub _ajax_zmenu_alignslice {
  my $self = shift;
  
  my $panel  = $self->_ajax_zmenu;
  my $object = $self->object;
  my $r      = $object->param('r');
  my $break  = $object->param('break');
  
  my @location = split /\b/, $r;
  my ($start, $end) = ($location[2], $location[4]);
  
  my ($start_type, $end_type);
  my $length = abs($end - $start);
  
  $panel->{'caption'} = 'AlignSlice';
  
  if ($break) {
    $length--;
    $start_type = 'From:';
    $end_type   = 'To:';
    
    $panel->{'caption'} .= ' Break';
    
    $panel->add_entry({
      'type'     => 'Info:',
      'label'    => 'There is a gap in the original chromosome between these two alignments',
      'priority' => 10
    });
  } else {
    my $strand   = $object->param('strand');
    my $interval = $object->param('interval');
    
    my ($i_start, $i_end) = split '-', $interval;
    
    $length++;
    $start_type = 'Start:';
    $end_type   = 'End:';
    
    $panel->add_entry({
      'type'     => 'Strand:',
      'label'    => $strand > 0 ? '+' : '-',
      'priority' => 8
    });
    
    $panel->add_entry({
      'type'     => 'Interval Start:',
      'label'    => $i_start,
      'priority' => 3
    });
    
    $panel->add_entry({
      'type'     => 'Interval End:',
      'label'    => $i_end,
      'priority' => 2
    });
    
    $panel->add_entry({
      'type'     => 'Interval Length:',
      'label'    => abs($i_end - $i_start) + 1,
      'priority' => 1
    });
  }
  
  $panel->add_entry({
    'type'     => 'Chromosome:',
    'label'    => $location[0],
    'priority' => 9
  });
  
  $panel->add_entry({
    'type'     => $start_type,
    'label'    => $start,
    'priority' => 7
  });
  
  $panel->add_entry({
    'type'     => $end_type,
    'label'    => $end,
    'priority' => 6
  });
  
  $panel->add_entry({
    'type'     => 'Length:',
    'label'    => $length,
    'priority' => 5
  });
  
  $panel->add_entry({
    'type'     => 'Link',
    'label'    => 'Region in detail',
    'link'     => $object->_url({ action => 'View' }),
    'priority' => 4
  });
}

1;
