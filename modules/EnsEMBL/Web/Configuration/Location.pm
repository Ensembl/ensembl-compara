package EnsEMBL::Web::Configuration::Location;

use strict;

use base qw( EnsEMBL::Web::Configuration );
use CGI;
use EnsEMBL::Web::TmpFile::Text;

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
sub context_panel  { return $_[0]->_context_panel;  }
sub configurator   { return $_[0]->_configurator;   }

sub export_configurator {
  my $self = shift;
  my $object = $self->object;
  
  return $self->ld_export_configurator if $object->action eq 'LD';
  
  my $misc_sets = $object->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'misc_feature'}{'sets'};
  my @misc_set_params = map { [ "miscset_$_", $misc_sets->{$_}->{'name'} ] } keys %$misc_sets;
  
  my $options = {
    'strand_values' => [
      { value => '1', name => 'Forward strand' },
      { value => '-1', name => 'Reverse strand' }
    ],
    'config_merge' => {
      'fasta' => {
        'params' => []
      },
      'features' => {
        'params' => [
          [ 'similarity', 'Similarity features' ],
          [ 'repeat', 'Repeat features' ],
          [ 'genscan', 'Prediction features (genscan)' ],
          [ 'variation', 'Variation features' ],
          [ 'gene', 'Gene Information' ],
          @misc_set_params
        ]
      }
    }
  };
  
  return $self->_export_configurator($options);
}

sub ld_export_configurator {
  my $self = shift;
  my $object = $self->{'object'};
  
  my $time = time;
  my $opt_pop = $object->parent->{'params'}->{'opt_pop'}->[0];
  
  my $href = $object->_url({
    'time' => $time, 
    'action' => 'Export', 
    'output' => 'ld', 
    'opt_pop' => $opt_pop 
  });
  
  # How confusing!
  my $form_action = $object->_url({
    'time' => $time,
    'action' => $object->type, 
    'type' => 'Export', 
    'function' => $object->action, 
    'opt_pop' => $opt_pop 
  }, 1);
  
  my $content;
  my $params;
  my @formats;

  my $text = qq{<p>Your export has been processed successfully. You can download the exported data by following the links below</p>};
  
  foreach (keys %{$form_action->[1]||{}}) {
    $params .= qq{
      <input type="hidden" name="$_" value="$form_action->[1]->{$_}" />};
      $form_action->[2] .= ";$_=$form_action->[1]->{$_}";
  }
  
  if ($object->param('haploview')) {    
    my ($gen_file, $locus_file, $tar_file) = $self->haploview_files($object);
    
    @formats = (
      [ 'Genotype file', '', ' rel="external"', ' [Genotypes in linkage format]', $gen_file ],
      [ 'Locus information', '', ' rel="external"', ' [Locus information file]', $locus_file ],
      [ 'Combined file', '', '', '', $tar_file ]
    );
    
    $params .= qq{<input type="submit" class="submit" value="&lt; Back" />};
  } elsif ($object->param('excel')) {
    my $excel_file  = new EnsEMBL::Web::TmpFile::Text(extension => 'xls', prefix => '');

    EnsEMBL::Web::Component::Location->ld_dump($object, $excel_file, $object->parent->{'params'});

    $excel_file->save;

    @formats = (
      [ 'Excel', '', '', '', $excel_file->URL ]
    );

    $params .= qq{<input type="submit" class="submit" value="&lt; Back" />};
  } else {
    @formats = (
      [ 'HTML', 'HTML', ' rel="external"' ],
      [ 'Text', 'Text', ' rel="external"' ],
      [ 'Excel', '', '', '', "$form_action->[0]?$form_action->[2];excel=1", 'modal_link'],
      [ 'For upload into Haploview software', '', '', ' [<a href="http://www.broad.mit.edu/mpg/haploview/" rel="external">Haploview website</a>]', "$form_action->[0]?$form_action->[2];haploview=1", 'modal_link' ]
    );

    $text = qq{<p>Please choose a format for your exported data</p>};
  }
  
  $content = qq{
    <h2>Export Configuration - LDView</h2>
    <form id="export_output_configuration" class="std check" method="get" action="$form_action->[0]">
      <fieldset>
        $text
        <ul>};
        
    foreach (@formats) {
      my $format = ";_format=$_->[1]" if $_->[1];
      my $link = $_->[4] || $href;
      my $class = $_->[5] || 'modal_close';
      
      $content .= qq{
          <li><a class="$class" href="$link$format"$_->[2]>$_->[0]</a>$_->[3]</li>};
    }
    
    $content .= qq{
      </ul>
      $params
    </form>};
      
  my $panel = $self->new_panel(
    'Configurator',
    'code' => 'configurator',
    'object'=> $object
  );
  
  $panel->set_content($content);

  $self->add_panel($panel);
}

sub haploview_files {
  my ($self, $object) = @_;
  
  my $gen_file = EnsEMBL::Web::TmpFile::Text->new(extension => 'ped', prefix => '');
  my $locus_file = EnsEMBL::Web::TmpFile::Text->new(
    filename => $gen_file->filename,
    extension => 'txt',
    prefix => ''
  );
  
  my %ind_genotypes;
  my %individuals;
  my @snps;
  my $family;
 
  my ($locus, $genotype);
 
  # gets all genotypes in the Slice as a hash. where key is region_name-region_start
  my $slice_genotypes = $object->get_all_genotypes;

  foreach my $vf (@{$object->get_variation_features}) {
    my ($genotypes, $ind_data) =  $object->individual_genotypes($vf, $slice_genotypes);

    next unless %$genotypes;
    
    my $name = $vf->variation_name;
    my $start = $vf->start;
    
    $locus .= "$name $start\r\n";
    
    push (@snps, $name);
    
    map { $ind_genotypes{$_}{$name} = $genotypes->{$_} } (keys %$genotypes);
    map { $individuals{$_} = $ind_data->{$_} } (keys %$ind_data);
  }
  
  foreach my $individual (keys %ind_genotypes) {
    my $output = join "\t", ("FAM" . $family++, 
      $individual, 
      $individuals{$individual}{'father'}, 
      $individuals{$individual}{'mother'}, 
      $individuals{$individual}{'gender'}, 
      "0\t"
    );
    
    foreach (@snps) {
      my $snp = $ind_genotypes{$individual}{$_} || "00";
      $snp =~ tr/ACGTN/12340/;
      
      $output .= join " ", (split (//, $snp));
      $output .= "\t";
    }
    
    $genotype .= "$output\r\n";
  }
  
  print $gen_file $genotype;
  print $locus_file $locus;
  
  $gen_file->save;
  $locus_file->save;
  
  my $tar_file = EnsEMBL::Web::TmpFile::Tar->new(
    filename => $gen_file->filename,
    prefix => '',
    use_short_names => 1
  );
  
  $tar_file->add_file($gen_file);
  $tar_file->add_file($locus_file);
  $tar_file->save;

  return ($gen_file->URL, $locus_file->URL, $tar_file->URL);
}

sub populate_tree {
  my $self = shift;

  $self->create_node( 'Genome', "Whole genome",
    [qw(genome EnsEMBL::Web::Component::Location::Genome)],
    { 'availability' => 'karyotype'},
  );

  $self->create_node( 'Chromosome', 'Chromosome summary',
    [qw(
        image           EnsEMBL::Web::Component::Location::ChromosomeImage
        change          EnsEMBL::Web::Component::Location::ChangeChromosome
        stats           EnsEMBL::Web::Component::Location::ChromosomeStats
    )],
    { 'availability' => 'chromosome',
      'disabled' => 'This sequence region is not part of an assembled chromosome' }
  );

  $self->create_node( 'Overview', "Region overview",
    [qw(
      nav    EnsEMBL::Web::Component::Location::ViewBottomNav/region
      top    EnsEMBL::Web::Component::Location::Region
    )],
    { 'availability' => 'slice'}
  );

  $self->create_node( 'View', "Region in detail",
    [qw(
      top     EnsEMBL::Web::Component::Location::ViewTop
      botnav  EnsEMBL::Web::Component::Location::ViewBottomNav
      bottom  EnsEMBL::Web::Component::Location::ViewBottom
    )],
#      zoomnav EnsEMBL::Web::Component::Location::ViewZoomNav
#      zoom    EnsEMBL::Web::Component::Location::ViewZoom
    { 'availability' => 'slice' }
  );

  my $align_menu = $self->create_submenu( 'Compara', 'Comparative Genomics' );
  $align_menu->append( $self->create_node( 'Compara_Alignments', 'Genomic alignments ([[counts::alignments]])',
    [qw(
      botnav  EnsEMBL::Web::Component::Location::ViewBottomNav
      selector   EnsEMBL::Web::Component::Compara_AlignSliceSelector
      alignments EnsEMBL::Web::Component::Location::Compara_Alignments
    )],
    { 'availability' => 'slice database:compara', 'concise' => 'Genomic alignments' }
  ));
#      top      EnsEMBL::Web::Component::Location::Compara_AlignSliceTop
#      selector EnsEMBL::Web::Component::Location::Compara_AlignSliceSelector
#      nav      EnsEMBL::Web::Component::Location::ViewBottomNav
#      bottom   EnsEMBL::Web::Component::Location::Compara_AlignSliceBottom

#      zoomnav EnsEMBL::Web::Component::Location::Compara_AlignSliceZoomNav
#      zoom    EnsEMBL::Web::Component::Location::Compara_AlignSliceZoom

#  $align_menu->append( $self->create_node( 'Comparison', "Multi-species comp. ([[counts::align_contig]])",
#    [qw(blank      EnsEMBL::Web::Component::Location::UnderConstruction)],
#    { 'availability' => 'slice database:compara', 'concise' => 'Multi-species comparison' }
#  ));
  $align_menu->append( $self->create_subnode( 'ComparaGenomicAlignment', '',
    [qw(gen_alignment      EnsEMBL::Web::Component::Location::ComparaGenomicAlignment)],
    {'no_menu_entry' => 1 }
  ));
  my $availability = $self->object->availability;
  my $caption = $availability->{'chromosome'} ? 'Synteny ([[counts::synteny]])' : 'Synteny';
  $align_menu->append( $self->create_node( 'Synteny', $caption,
    [qw(
      image      EnsEMBL::Web::Component::Location::SyntenyImage
      species    EnsEMBL::Web::Component::Location::ChangeSpecies
      change     EnsEMBL::Web::Component::Location::ChangeChromosome
      homo_nav   EnsEMBL::Web::Component::Location::NavigateHomology
      matches    EnsEMBL::Web::Component::Location::SyntenyMatches
    )],
    { 'availability' => 'chromosome has_synteny', 'concise' => 'Synteny'}
  ));
  my $variation_menu = $self->create_submenu( 'Variation', 'Genetic Variation' );
  $caption = $availability->{'slice'} ? 'Resequencing ([[counts::reseq_strains]])' : 'Resequencing';
  $variation_menu->append( $self->create_node( 'SequenceAlignment', $caption,
    [qw(botnav  EnsEMBL::Web::Component::Location::ViewBottomNav
	      align   EnsEMBL::Web::Component::Location::SequenceAlignment)],
    { 'availability' => 'slice has_strains', 'concise' => 'Resequencing Alignments' }
  ));
  $variation_menu->append( $self->create_node( 'LD', "Linkage Data ",
    [qw(ld  EnsEMBL::Web::Component::Location::LD
        ldimage  EnsEMBL::Web::Component::Location::LDImage)],
    { 'availability' => 'slice has_LD', 'concise' => 'Linkage Disequilibrium Data' }
  ));
#EnsEMBL::Web::Component::Location::LD)],

  $self->create_node( 'Marker', "Markers",
     [ qw(botnav  EnsEMBL::Web::Component::Location::ViewBottomNav
	  marker EnsEMBL::Web::Component::Location::MarkerDetails) ],
     { 'availability' => 'slice' }
  );

  $self->create_subnode(
    'Export', "Export location data",
    [ qw( export EnsEMBL::Web::Component::Location/export ) ],
    { 'availability' => 'slice', 'no_menu_entry' => 1 }
  );
}

sub ajax_zmenu      {
  my $self = shift;
  my $panel = $self->_ajax_zmenu;
  my $obj  = $self->object;
  my $action = $obj->[1]{'_action'} || 'Summary';
  if( $action =~ 'Regulation'){
    return $self->_ajax_zmenu_regulation($panel, $obj);
  }
  if( $action =~/Variation/){
    return $self->ajax_zmenu_variation($panel, $obj);
  }
  elsif( $action =~ /Genome/) {
    return $self->_ajax_zmenu_alignment($panel,$obj);
  }
  elsif ( $action =~ /Marker/) {
    return $self->_ajax_zmenu_marker($panel,$obj);
  }
  elsif ($action eq 'ComparaGenomicAlignment') {
    return $self->_ajax_zmenu_ga($panel,$obj);
  }
  elsif ($action eq 'Align') {
    return $self->_ajax_zmenu_av($panel,$obj);
  }
  elsif ($action =~ /View|Overview/) {
    return $self->_ajax_zmenu_view($panel,$obj);
  }
  return;
}

sub _ajax_zmenu_view {
  my $self  = shift;
  my $panel = shift;
  my $obj   = shift;
  if( $obj->param('mfid')) {
    return $self->_ajax_zmenu_misc_feature($panel,$obj);
  } elsif ($obj->param('region_n')) {
    return $self->_ajax_zmenu_region($panel,$obj);
  } elsif ($obj->param('r1') || $obj->param('ori')) {
    return $self->_ajax_zmenu_synteny($panel,$obj);
  } else {
    #otherwise simply show a link to View/Overview
    my $r             = $obj->param('r');
    my ($chr, $loc)   = split ':', $r;
    my ($start,$stop) = split '-', $loc;
    my $action        = $obj->[1]{'_action'} || 'View';
    my $threshold     = 1000100 * ($obj->species_defs->ENSEMBL_GENOME_SIZE||1);

    #go to Overview if region too large for View
    $action = 'Overview' if ( ($stop-$start+1 > $threshold) && $action eq 'View') ;
    $panel->{'caption'} = $r;
    my $url             = $obj->_url({
	'type' => 'Location',
	'action' => $action});
    $panel->add_entry({ 'label' => $r, 'link'  => $url });
  }
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
#    $referer = $obj->_url({'type'=>'Location','action'=>"$action",'r'=>undef,'region'=>$new_slice_name});

    #would be nice if exportview could work with the region parameter, either in the referer or in the real URL
    #since it doesn't we have to explicitly calculate the locations of all regions on top level
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
	'link'     => $obj->get_ExtURL('EMBL',$new_slice_name),
	'priority' => $priority,
      });
      $priority--;
      $panel->add_entry({
	'type'     => 'EMBL (latest version)',
	'label'    => $short_name,
	'link'     => $obj->get_ExtURL('EMBL',$short_name),
	'priority' => $priority,
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

  #add entries for each of the following attributes
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

    #hacks for these type of entries
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

    #this is all for pre so can be sorted for that when the time comes
    #my $links = $self->my_config('LINKS');
    #if( $links ) {
    #	my $Z = 80;
    #	foreach ( @$links ) {
    #	    my $val = $f->get_scalar_attribute($_->[1]);
    #   next unless $val;
    #	    (my $href = $_->[2]) =~ s/###ID###/$val/g;
    #	    $zmenu->{"$Z:$_->[0]: $val"} = $href;
    #	    $Z++;
    #	}
    #}

}

sub _ajax_zmenu_av {
  my $self = shift;
  my $panel = shift;
  my $obj  = shift;
  my $id = $obj->param('id');
  my $obj_type  = $obj->param('ftype');
  my $align = $obj->param('align');
  my $hash = $obj->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'};
  my $caption = $hash->{$align}{'name'};;
  my $url = $obj->_url({'type'=>'Location','action'=>'Align','align'=>$align});
  my ($chr, $start, $end) = split(/[\:\-]/, $obj->param('r'));
  #if there's a score than show it and also change the name of the track (hacky)
  if ($obj_type and $id) {
    my $db_adaptor   = $obj->database("compara");
    my $adaptor_name = "get_${obj_type}Adaptor";
    my $feat_adap =  $db_adaptor->$adaptor_name;
    my $feature = $feat_adap->fetch_by_dbID($id);
    if ($obj_type eq "ConstrainedElement") {
      $panel->add_entry({
        'type'  => 'p-value',
        'label' => sprintf("%.2e", $feature->p_value),
        'priority' => 107,
      }) if ($feature->p_value);
      $panel->add_entry({
        'type'  => 'Score',
        'label' => sprintf("%.2f", $feature->score),
        'priority' => 106,
      });
      if ($caption =~ /^(\d+)/) {
        $caption = "Constrained el. $1 way";
      }
      my @alignment_segments = sort {$a->[3] cmp $b->[3]} @{$feature->alignment_segments};
      for (my $i = 0; $i < @alignment_segments; $i++) {
        my $segment = $alignment_segments[$i];
        my ($dnafrag_id, $start, $end, $genome_db_name, $dnafrag_name) = @$segment;
        my $seg_url = "/$genome_db_name/Location/View?r=$dnafrag_name:$start-$end";
        $seg_url =~ s/ /_/g;
        $panel->add_entry({
          'type' => $genome_db_name,
          'label' => "View region (".($end-$start+1)." bp)",
          'link' => $seg_url,
          'priority' => 99 - $i,
        });
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
    'priority' => 100, #default
  });
  return;
}

sub _ajax_zmenu_ga {
  my $self   = shift;
  my $panel  = shift;
  my $obj    = shift;
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
  my $url = $obj->_url({'type'    => 'Location',
			'action'  => 'View',
			'species' => $sp1,
			'r'       => $r1} );
  $panel->add_entry({
    'label'    => "Jump to $sp1",
    'link'     => $url,
    'priority' => 150,
  });

  if ($obj->param('method')) {
    $url = $obj->_url({'type'  =>'Location',
		       'action'=>'ComparaGenomicAlignment',
		       's1'    =>$sp1,
		       'r1'    =>$obj->param('r1'),
		       'method'=>$obj->param('method')} );
    $panel->add_entry({
      'label'    => 'View alignment',
      'link'     => $url,
      'priority' => 100,
    });

    $url = $obj->_url({'type'  =>'Location',
		       'action'=>'View',
		       'r'     =>$obj->param('r')} );
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
  my $panel = shift;
  my $obj  = shift;
  my $caption = $obj->param('m');
  $panel->{'caption'} = $caption;
  my $url = $obj->_url({'type'=>'Location','action'=>'Marker','m'=>$caption});
  $panel->add_entry({
    'label' => 'Marker info.',
    'link'  => $url,
  });
  return;
}


#zmenu for aligments (directed to /Location/Genome)
sub _ajax_zmenu_alignment {
  my $self = shift;
  my $panel = shift;
  my $obj  = shift;
  my $id        = $obj->param('id');
  my $obj_type  = $obj->param('ftype');
  my $db        = $obj->param('db')  || 'core';
  my $db_adaptor = $obj->database(lc($db));
  my $adaptor_name = "get_${obj_type}Adaptor";
  my $feat_adap =  $db_adaptor->$adaptor_name;
  my $fs = $feat_adap->can( 'fetch_all_by_hit_name' ) ? $feat_adap->fetch_all_by_hit_name($id)
    : $feat_adap->can( 'fetch_all_by_probeset' ) ? $feat_adap->fetch_all_by_probeset($id)
    :                                              []
    ;
  my $external_db_id = ($fs->[0] && $fs->[0]->can('external_db_id')) ? $fs->[0]->external_db_id : '';
  my $extdbs = $external_db_id ? $obj->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'external_db'}{'entries'} : {};
  my $hit_db_name = $extdbs->{$external_db_id}{'db_name'} || 'External Feature';
  #hack to link sheep bac ends to trace archive
  if ($fs->[0]->analysis->logic_name =~ /sheep_bac_ends|BACends/) {
    $hit_db_name = 'TRACE';
  }

  my $species= $obj->species;

  #different zmenu for oligofeatures
  if ($obj_type eq 'OligoFeature') {
    my $array_name = $obj->param('array') || '';
    $panel->{'caption'} = "Probe set: $id";
    my $fv_url = $obj->_url({'type'=>'Location','action'=>'Genome','ftype'=>$obj_type,'id'=>$id,'db'=>$db});
    my $p = 50;
    $panel->add_entry({ 
      'label' => 'View all probe hits',
      'link'   => $fv_url,
      'priority' => $p,
    });

    #details of each probe within the probe set on the array that are found within the slice
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
  }

  else {
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

sub _ajax_zmenu_regulation {
 # Specific zmenu for functional genomics features

  my $self = shift;
  my $panel = $self->_ajax_zmenu;
  my $obj = $self->object;
  my $fid = $obj->param('fid') || die( "No feature ID value in params" );
  my $ftype = $obj->param('ftype')  || die( "No feature type value in params" );
  my $db_adaptor = $obj->database('funcgen');
  my $ext_adaptor =  $db_adaptor->get_ExternalFeatureAdaptor();
  my $species= $obj->species;

  if ($ftype eq 'ensembl_reg_feat'){
    my $rf_adaptor = $db_adaptor->get_RegulatoryFeatureAdaptor();
    my $reg_feat = $rf_adaptor->fetch_by_stable_id($fid);
    my $location = $reg_feat->slice->seq_region_name .":". $reg_feat->start ."-" . $reg_feat->end;
    my $location_link = $obj->_url({'type' => 'Location', 'action' => 'View', 'r' => $location});

    my @atts  = @{$reg_feat->regulatory_attributes()};
    my @temp = map $_->feature_type->name(), @atts;
    my %att_label;
    my $c = 1;
    foreach my $k (@temp){
      if (exists  $att_label{$k}) {
        my $old = $att_label{$k};
        $old++;
        $att_label{$k} = $old;
      } else {
        $att_label{$k} = $c;
      }
    }
    my @keys = keys %att_label;
    my $label = "";
    foreach my $k (keys %att_label){
      my $v = $att_label{$k};
      $label .= "$k($v), ";
    }
    $label =~s/\,\s$//;

    $panel->{'caption'} = "Regulatory Feature";
    $panel->add_entry({
        'type'     =>  'Stable ID:',
        'label'    =>  $reg_feat->stable_id,
        'priority' =>  10,
    });
    $panel->add_entry({
        'type'     =>  'Type:',
        'label'    =>  $reg_feat->feature_type->name,
        'priority' =>  9,
    });
    $panel->add_entry({
        'type'        =>  'bp:',
        'label_html'  =>  $location,
        'link'        =>  $location_link,
        'priority'    =>  8,
    });
    $panel->add_entry({
        'type'     =>  'Attributes:',
        'label'    =>  $label,
        'priority' =>  7,
    });
  } else { 
    my $feature = $ext_adaptor->fetch_by_dbID($obj->param('dbid'));
    my $location = $feature->slice->seq_region_name .":". $feature->start ."-" . $feature->end;
    my $location_link = $obj->_url({'type' => 'Location', 'action' => 'View', 'r' => $location});
    my ($feature_link, $factor_link);
    my $factor = $obj->param('fid'); 
    $panel->{'caption'} = "Regulatory Region";
 

    if ($ftype eq 'cisRED'){
      $factor =~s/\D*//g;
      $feature_link = $self->object->species_defs->ENSEMBL_EXTERNAL_URLS->{'CISRED'};
      $factor_link = "/$species/Location/Genome?ftype=RegulatoryFactor;dbid=".$obj->param('dbid').";id=" . $obj->param('fid');
      $feature_link =~s/###ID###/$factor/;
    } elsif($ftype eq 'miRanda'){
      my $name = $obj->param('fid');
      $name =~/\D+(\d+)/;
      my $temp_factor = $name;
      my @temp = split (/\:/, $temp_factor);
      $factor = $temp[1];  
      $factor_link = "/$species/Location/Genome?ftype=RegulatoryFactor;id=$factor;name=" . $obj->param('fid');

    } elsif($ftype eq 'vista_enhancer'){
      $factor_link = "/$species/Location/Genome?ftype=RegulatoryFactor;id=$factor;name=" . $obj->param('fid');

    }elsif($ftype eq 'NestedMICA'){
       $factor_link = "/$species/Location/Genome?ftype=RegulatoryFactor;id=$factor;name=" . $obj->param('fid');
       $feature_link = "http://servlet.sanger.ac.uk/tiffin/motif.jsp?acc=".$obj->param('fid');

    } elsif($ftype eq 'cisred_search'){
      my ($id, $type, $analysis_link, $associated_link, $gene_reg_link);
      my $db_ent = $feature->get_all_DBEntries;
      foreach my $dbe (@$db_ent){
        $id = $dbe->primary_id;
        my $dbname = $dbe->dbname;
        if ($dbname =~/gene/i){
          $associated_link = $obj->_url({'type' => 'Gene', 'action'=> 'Summary', 'g' => $id });
          $gene_reg_link = $obj->_url({'type' => 'Gene', 'action'=> 'Regulation', 'g' => $id });
          $analysis_link = $self->object->species_defs->ENSEMBL_EXTERNAL_URLS->{'CISRED'};
          $analysis_link =~s/siteseq\?fid=###ID###/gene_view?ensembl_id=$id/;
        } elsif ($dbname =~/transcript/i){
          $associated_link = $obj->_url({'type' => 'Transcript', 'action'=> 'Summary', 't' => $id });
        } elsif ($dbname =~/transcript/i){
          $associated_link = $obj->_url({'type' => 'Transcript', 'action'=> 'Summary', 'p' => $id });
        } 
      }
     
      $panel->{'caption'} = "Regulatory Search Region";
      $panel->add_entry({
        'type'        =>  'Analysis:',
        'label_html'  =>  $obj->param('ftype'),
        'link'        =>  $analysis_link,
        'priority'    =>  7,
      });
      $panel->add_entry({
        'type'        =>  'Target Gene:',
        'label_html'  =>  $id,
        'link'        =>  $associated_link,          
        'priority' =>  6,
      });
      $panel->add_entry({
        'label_html'  =>  'View Gene Regulation',
        'link'        =>  $gene_reg_link,
        'priority' =>  4,
      });

    }
      
    ## add zmenu items that apply to all external regulatory features
    unless ($ftype eq 'cisred_search'){
      $panel->add_entry({
        'type'        =>  'Feature:',
        'label_html'  =>  $obj->param('fid'),
        'link'        =>  $feature_link,
        'priority'    =>  10,
      });
      $panel->add_entry({
        'type'        =>  'Factor:',
        'label_html'  =>  $factor,
        'link'        =>  $factor_link,
        'priority'    =>  9,
      }) ;
    }
    $panel->add_entry({
      'type'        =>  'bp:',
      'label_html'  =>  $location,
      'link'        =>  $location_link,
      'priority'    =>  8,
    });

  }
 
  return;
}

############################ OLD CODE! ###############################################################


### Functions to configure contigview, ldview etc

###   The description of each component indicates the usual Panel subtype e.g. Panel::Image.
###  my $info_panel = $self->new_panel( "Information",
###    "code"    => "info#",
###     "caption"=> "Linkage disequilibrium report: [[object->type]] [[object->name]]"
### 				   )) {
###
###     $info_panel->add_components(qw(
###     focus                EnsEMBL::Web::Component::LD::focus
###     prediction_method    EnsEMBL::Web::Component::LD::prediction_method
###     population_info      EnsEMBL::Web::Component::LD::population_info
### 				  ));
###     $self->{page}->content->add_panel( $info_panel );

sub load_configuration {
  my ($self, $config) = @_;
  my $obj  = $self->{object};
  my $config_string = $config->config;
  $config_string =~ s/&quote;/'/g;
#  warn $config_string;
  my $config_data = eval($config_string);
  foreach my $key (keys %{ $config_data }) {
    #warn "ADDING CONFIG SETTINGS FOR: " . $key;
    my $wuc = $obj->image_config_hash($key);
    $wuc->{'user'} = $config_data;
#    $wuc->save;
  }
}


sub sequencealignview {
  my $self = shift;

  my $region_name = $self->{object}->slice->name;

  $self->set_title( "Sequence Alignment for $region_name");
  if( my $panel1 = $self->new_panel( 'Information',
	'code'    => "info#",
	'caption' => "Sequence Alignment for $region_name",
     ) ) {

	$panel1->add_components(qw(
	        markup_options EnsEMBL::Web::Component::Slice::sequence_markup_options
	        sequence       EnsEMBL::Web::Component::Slice::sequencealignview
	));

	$self->add_panel( $panel1 );
  }
}

sub export_step1 {
  ### Alternative context menu for step 1 of exportview
  my $self = shift;
  my $obj  = $self->{object};
  my $species = $obj->real_species;
  return unless $self->{page}->can('menu');
  my $menu = $self->{page}->menu;
  return unless $menu;

  my $flag = 'species';
  $menu->add_block( $flag, 'bulleted', 'Export a different species', 'raw' => 1 );


  my @species_inconf = @{$obj->species_defs->ENSEMBL_SPECIES};
  my @group_order = qw( Mammals Chordates Eukaryotes );
  my %spp_tree = (
      'Mammals'   => { 'label'=>'Mammals',          'species' => [] },
      'Chordates' => { 'label'=>'Other chordates',  'species' => [] },
      'Eukaryotes'=> { 'label'=>'Other eukaryotes', 'species' => [] },
    );

  foreach my $sp ( @species_inconf) {
    my $bio_name = $obj->species_defs->other_species($sp, "SPECIES_BIO_NAME");
    my $group    = $obj->species_defs->other_species($sp, "SPECIES_GROUP") || 'default_group';
    unless( $spp_tree{ $group } ) {
      push @group_order, $group;
      $spp_tree{ $group } = { 'label' => $group, 'species' => [] };
    }
    my $hash_ref = { 'href'=>"/$sp/exportview", 'text'=>"<i>$bio_name</i>", 'raw'=>1 };
    push @{ $spp_tree{$group}{'species'} }, $hash_ref;
  }
  foreach my $group (@group_order) {
    next unless @{ $spp_tree{$group}{'species'} };
    my $text = $spp_tree{$group}{'label'};
    $menu->add_entry(
      'species',
      'href'=>'/',
      'text'=>$text,
      'options'=>$spp_tree{$group}{'species'},
	  'code' => 'export_'.$group,
    );
  }
}

sub exportview {
  my $self = shift;
  my $obj  = $self->{object};
  $self->add_format( 'flat',  'Flat File', 'EnsEMBL::Web::Component::Export::flat_form', 'EnsEMBL::Web::Component::Export::flat',
    'embl' => 'EMBL', 'genbank' => 'GenBank'
  );
  $self->add_format( 'fasta', 'FASTA File', 'EnsEMBL::Web::Component::Export::fasta_form', 'EnsEMBL::Web::Component::Export::fasta',
    'fasta' => 'FASTA sequence',
  );
  $self->add_format( 'features', 'Feature List', 'EnsEMBL::Web::Component::Export::features_form', 'EnsEMBL::Web::Component::Export::features',
    'gff' => 'GFF format', 'tab' => 'Tab separated values', 'csv' => 'CSV (Comma Separated values)' );
  $self->add_format( 'pipmaker', 'PIP (%age identity plot)', 'EnsEMBL::Web::Component::Export::pip_form', undef,
    'pipmaker' => 'Pipmaker / zPicture format', 'vista'    => 'Vista Format' );

  if( $obj->seq_region_name ) {
    if( $obj->param('type2') eq 'none' || ! $obj->param('anchor2') ) {
      if( $obj->param('type1') eq 'transcript' || $obj->param('type1') eq 'peptide' ) {
        $self->{object}->alternative_object_from_factory( 'Transcript' );
        if( ( @{$self->{object}->__data->{'objects'}||[]}) && !@{ $self->{object}->__data->{'transcript'}||[]} ) {
          $self->{object}->param('db', $self->{object}->__data->{'objects'}->[0]{'db'});
          $self->{object}->param('transcript', $self->{object}->__data->{'objects'}->[0]{'transcript'});
          $self->{object}->alternative_object_from_factory( 'Transcript' );
        }
      } elsif( $obj->param('type1') eq 'gene' ) {
        $self->{object}->alternative_object_from_factory( 'Gene' );
        if( ( @{$self->{object}->__data->{'objects'}||[]}) && !@{ $self->{object}->__data->{'gene'}||[]} ) {
          $self->{object}->param('db', $self->{object}->__data->{'objects'}->[0]{'db'});
          $self->{object}->param('gene', $self->{object}->__data->{'objects'}->[0]{'gene'});
          $self->{object}->alternative_object_from_factory( 'Gene' );
        }
      }
    }
    $self->{object}->clear_problems();
    if( $obj->param('action') ) {
      my $format = $self->get_format( $obj->param('format') );
      if( $format ) {
        if( $obj->param('action') eq 'export') {
          my $panel3 = $self->new_panel( '',
            'code' => 'stage3',
            'caption' => 'Results',
          );
          $panel3->add_components( 'results' => $format->{'superdisplay'} );
          $self->add_panel( $panel3 );
          return;
        } else {
          my $panel2 = $self->new_panel( '',
            'code'    => 'stage2_form',
            'caption' => qq(Configure $format->{'supername'} output for $format->{'name'})
          );
          $panel2->add_components( qw(select EnsEMBL::Web::Component::Export::stage2) );
          $self->add_panel( $panel2 );
          return;
        }
      }
    }
  } else {
    if( $obj->param('format') ) {
      ## We have an error here... so we will need to pass it through to the webform...
    }
  }
  ## Display the form...
  my $panel1 = $self->new_panel( '',
    'code'    => 'stage1_form',
    'caption' => qq(Select region/feature to Export)
  );
  $panel1->add_components( qw(stage1 EnsEMBL::Web::Component::Export::stage1) );
  $self->add_panel( $panel1 );
}

sub miscsetview {
  my $self = shift;
  my $obj  = $self->{object};
  my $output_type = $obj->param( 'dump' );
  my $set         = '';
  my $misc_set;
  foreach my $set ( $obj->param( 'set' ), 'cloneset', 'cloneset_1mb' ) {
    eval {
      $misc_set = $obj->database('core')->get_MiscSetAdaptor->fetch_by_code($set);
    };
    last if $misc_set && !$@;
  }
  if( $misc_set ) {
    $obj->misc_set_code( $misc_set->code );
    $set                = $misc_set->name;
  }
  return unless $set;
  my %output_types = (
    'set'   => "Features in set $set on @{[$obj->seq_region_type_and_name]}",
    'slice' => "Features in set $set in @{[ $obj->seq_region_type_and_name, $obj->seq_region_start, '-', $obj->seq_region_end ]}",
    'all'   => "Features in set $set"
  );
  my $output_name = $output_types{ $output_type };
  unless( $output_name ) {
    $output_type = 'set';
    $output_name = $output_types{ $output_type };
  }
  my $panel = $self->new_panel( 'SpreadSheet',
    'code'    => "miscset_$self->{flag}",
    'caption' => $output_name,
  );
  $panel->add_components( 'features' => "EnsEMBL::Web::Component::MiscSet::spreadsheet_miscset_$output_type" );
  $self->{page}->content->add_panel( $panel );
  if( $output_type eq 'slice' ) {
    my $panel2 = $self->new_panel( 'SpreadSheet',
      'code'    => "miscset_#",
      'caption' => "Genes in @{[ $obj->seq_region_type_and_name, $obj->seq_region_start, '-', $obj->seq_region_end ]}"
    );
    $panel2->add_components( 'genes' => "EnsEMBL::Web::Component::MiscSet::spreadsheet_miscset_genes" );
    $self->{page}->content->add_panel( $panel2 );
  }
}

sub add_das_sources {
  my( $self, $scriptname ) = @_;
  my $obj    = $self->{object};
  my @T = $obj->param('das_sources');
  @T = grep {$_} @T;
  if( @T ) {
    my $wuc = $obj->image_config_hash( $scriptname );
    foreach my $source (@T) {
      $wuc->set("managed_extdas_$source", 'on', 'on', 1);
    }
#    $wuc->save;
  }
}

sub top_start_end {
  my( $self, $obj, $max_length ) = @_;
  my($start,$end) = ($obj->seq_region_start,$obj->seq_region_end);
  if( $obj->seq_region_length < $max_length || $obj->length >= $obj->seq_region_length ) {
    $start = 1;
    $end   = $obj->seq_region_length;
  } elsif( $obj->length < $max_length ) {
    $start -= ( $max_length - $obj->length ) / 2;
    $end   += ( $max_length - $obj->length ) / 2;
    if( $start < 1 ) {
      $start = 1;
      $end   = $start + $max_length - 1;
    } elsif( $end > $obj->seq_region_length ) {
      $end   = $obj->seq_region_length;
      $start = $end - $max_length + 1;
    }
  }
  return ( $start, $end );
}


sub alignsliceview {
  my $self   = shift;
  my $obj    = $self->{object};
  my $species    = $obj->species;
  my $q_string = sprintf( '%s:%s-%s', $obj->seq_region_name, $obj->seq_region_start, $obj->seq_region_end );

  my $config_name = 'alignsliceviewbottom';
  $self->update_configs_from_parameter( 'bottom', $config_name );

  my $wsc = $self->{object}->get_viewconfig();
  my $wuc = $obj->image_config_hash( $config_name );

  my @align_modes = grep { /opt_align/ }keys (%{$wsc->{_options}});
  if (my $set_align = $obj->param('align')) {
    foreach my $opt (@align_modes) {
      $wsc->set($opt, "off", 1);
    }
#warn "SETTING.... $set_align on";
    $wsc->set($set_align, "on", 1);
#warn "$set_align....";
    $wuc->set('alignslice', 'align', $set_align, 1);
#   $wsc->save();
  }

    ## Unset conservation_scores and constrained_elements
  $wuc->set( 'alignslice',  'constrained_elements', "", 1);
  $wuc->set( 'alignslice',  'conservation_scores', "", 1);

  foreach my $opt (@align_modes) {
    #warn "$opt - ",$wsc->get($opt,"on");
    if( $wsc->get($opt, "on") eq 'on' ) {
      my ($atype, $id);
      my @selected_species;
      if ($opt =~ /^opt_align_(.*)/) {
        $id = $1;
        my @align_species = grep { /opt_${id}_/ } keys (%{$wsc->{_options}});
        foreach my $sp (@align_species) {
          if ($sp =~ /opt_${id}_constrained_elem/) {
            if ($wsc->get($sp, "on") eq 'on') {
              $wuc->set( 'alignslice',  'constrained_elements', "on", 1);
            }
            next;
          }
          if ($sp =~ /opt_${id}_conservation_score/) {
            if ($wsc->get($sp, "on") eq 'on') {
              $wuc->set( 'alignslice',  'conservation_scores', "on", 1);
            }
            next;
          }
          if ($wsc->get($sp, "on") eq 'on') {
            $sp =~ s/opt_${id}_//;
            push @selected_species, $sp if ($sp ne $species);
          }
        }
      }
# 	    warn("STEP1: ($opt : $id : @selected_species )");
      $wuc->set( 'alignslice',  'id', $id, 1);
      $wuc->set( 'alignslice',  'species', \@selected_species, 1);
      $wuc->set( 'alignslice',  'align', $opt, 1);
      last;
    }
  }
#    $wuc->save();
  $obj->get_session->_temp_store( 'alignsliceview' , 'alignsliceviewbottom' );
  my $last_rendered_panel = undef;
  my @common = ( 'params' => { 'l'=>$q_string, 'h' => $obj->highlights_string } );

    ## Initialize the ideogram image...
    my $ideo = $self->new_panel( 'Image',
				 'code'    => "ideogram_#", 'caption' => $obj->seq_region_type_and_name, 'status'  => 'panel_ideogram', @common
                                );
     $last_rendered_panel = $ideo if $obj->param('panel_ideogram') ne 'off';
     $ideo->add_components(qw(image EnsEMBL::Web::Component::Location::ideogram_old));
     $self->{page}->content->add_panel( $ideo );

    ## Now the overview panel...
    my $over = $self->new_panel( 'Image',
				 'code'    => "overview_#", 'caption' => 'Overview', 'status'  => 'panel_top', @common
				 );
    my $max_length = ($obj->species_defs->ENSEMBL_GENOME_SIZE||1) * 1.001e6;
    if( $obj->param('panel_top') ne 'off' ) {
	my($start,$end) = $self->top_start_end( $obj, $max_length );
	#$last_rendered_panel->add_option( 'red_box' , [ $start, $end ] ) if $last_rendered_panel;
	$over->add_option( 'start', $start );
	$over->add_option( 'end',   $end   );
	$over->add_option( 'red_edge', 'yes' );
	$last_rendered_panel = $over;
    }
    $over->add_components(qw(image EnsEMBL::Web::Component::Location::alignsliceviewtop));
    $self->{page}->content->add_panel( $over );

    $self->initialize_zmenu_javascript;
    $self->initialize_ddmenu_javascript;

    my $bottom = $self->new_panel( 'Image',
				   'code'    => "bottom_#", 'caption' => 'Detailed view', 'status'  => 'panel_bottom', @common
				   );

    ## Big switch time....
    if( $obj->length > $max_length ) {
	$bottom->add_components(qw(
                                  menu  EnsEMBL::Web::Component::Location::alignsliceviewbottom_menu
                                  nav   EnsEMBL::Web::Component::Location::alignsliceviewbottom_nav
                                  text  EnsEMBL::Web::Component::Location::alignsliceviewbottom_text
				   ));
       $self->{page}->content->add_panel( $bottom );
    } else {
	if( $obj->param('panel_bottom') ne 'off' ) {
	    if( $last_rendered_panel ) {
		#$last_rendered_panel->add_option( 'red_box' , [ $obj->seq_region_start, $obj->seq_region_end ] );
		$bottom->add_option( 'red_edge', 'yes' );
	    }
	    $last_rendered_panel = $bottom;
	}
	$bottom->add_components(qw(
				   menu  EnsEMBL::Web::Component::Location::alignsliceviewbottom_menu
				   nav   EnsEMBL::Web::Component::Location::alignsliceviewbottom_nav
				   image EnsEMBL::Web::Component::Location::alignsliceviewbottom
				   ));
	$self->{page}->content->add_panel( $bottom );
	my $base = $self->new_panel( 'Image',
				     'code'    => "basepair_#", 'caption' => 'Basepair view', 'status'  => 'panel_zoom', @common
				     );
       if( $obj->param('panel_zoom') ne 'off' ) {
           my $zw = int(abs($obj->param('zoom_width')));
              $zw = 1 if $zw <1;

           my( $start, $end ) = $obj->length < $zw ? ( $obj->seq_region_start, $obj->seq_region_end ) : ( $obj->centrepoint - ($zw-1)/2 , $obj->centrepoint + ($zw-1)/2 );
           $base->add_option( 'start', $start );
           $base->add_option( 'end',   $end );
           if( $last_rendered_panel ) {
               #$last_rendered_panel->add_option( 'red_box' , [ $start, $end ] );
               $bottom->add_option( 'red_edge', 'yes' );
           }
           $last_rendered_panel = $base;
       }
       $base->add_components(qw(
                                nav   EnsEMBL::Web::Component::Location::alignsliceviewzoom_nav
                                image EnsEMBL::Web::Component::Location::alignsliceviewzoom
                                ));
       $self->{page}->content->add_panel( $base );
     }
    $self->{page}->set_title( "Features on ".$obj->seq_region_type_and_name.' '.$self->{object}->seq_region_start.'-'.$self->{object}->seq_region_end );
}


###############################################################################
## Helper functions....
###############################################################################
## add_format, get_format are helper functions for configuring ExportView #####
###############################################################################

sub add_format {
  my( $self, $code, $name, $form, $display, %options ) = @_;
  unless( $self->{object}->__data->{'formats'}{$code} ) {
    $self->{object}->__data->{'formats'}{$code} = {
      'name' => $name, 'form' => $form, 'display' => $display, 'sub'  => {}
    };
    foreach ( keys %options ) {
      $self->{object}->__data->{'formats'}{$code}{'sub'}{$_} = $options{$_};
    }
  }
}

sub get_format {
  my( $self, $code ) = @_;
  my $formats = $self->{object}->__data->{'formats'};
  foreach my $super ( keys %$formats ) {
    foreach ( keys %{$formats->{$super}{'sub'}} ) {
      return {
        'super'        => $super,
        'supername'    => $formats->{$super}{'name'},
        'superform'    => $formats->{$super}{'form'},
        'superdisplay' => $formats->{$super}{'display'},
        'code'         => $_,
        'name'         => $formats->{$super}{'sub'}{$_}
      } if $code eq $_;
    }
  }
}

1;
