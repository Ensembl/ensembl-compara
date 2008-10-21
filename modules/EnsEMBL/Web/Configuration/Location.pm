package EnsEMBL::Web::Configuration::Location;

use strict;

use base qw( EnsEMBL::Web::Configuration );

sub set_default_action {
  my $self = shift;
  my $x = $self->object->availability || {};
  if( $x->{'slice'} ) {
    $self->{_data}{default} = 'View';
  } elsif( $x->{'chromosome'} ) {
    $self->{_data}{default} = 'Chromosome';
  } else {
    $self->{_data}{default} = 'Karyotype';
  }
}

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;    }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }
sub configurator   { return $_[0]->_configurator;   }

sub populate_tree {
  my $self = shift;

  $self->create_node( 'Karyotype', "Karyotype",
    [qw(image EnsEMBL::Web::Component::Location::KaryotypeImage)],
    { 'availability' => 'karyotype',
      'disabled' => 'This genome is not assembled into chromosomes'}
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
  $align_menu->append( $self->create_node( 'Align', "Genomic alignments ([[counts::align_slice]])",
    [qw(
      top      EnsEMBL::Web::Component::Location::Compara_AlignSliceTop
      nav      EnsEMBL::Web::Component::Location::ViewBottomNav
      bottom   EnsEMBL::Web::Component::Location::Compara_AlignSliceBottom
    )],
#      zoomnav EnsEMBL::Web::Component::Location::Compara_AlignSliceZoomNav
#      zoom    EnsEMBL::Web::Component::Location::Compara_AlignSliceZoom
    { 'availability' => 'slice database:compara', 'concise' => 'Genomic alignments' }
  ));
  $align_menu->append( $self->create_node( 'Comparison', "Multi-species comp. ([[counts::align_contig]])",
    [qw(blank      EnsEMBL::Web::Component::Location::UnderConstruction)],
    { 'availability' => 'slice database:compara', 'concise' => 'Multi-species comparison' }
  ));
  $align_menu->append( $self->create_node( 'Synteny', "Synteny ([[counts::synteny]])",
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
  $variation_menu->append( $self->create_node( 'SequenceAlignment', "Resequencing ([[counts::reseq_strains]])",
    [qw(botnav  EnsEMBL::Web::Component::Location::ViewBottomNav
	align   EnsEMBL::Web::Component::Location::SequenceAlignment)],
    { 'availability' => 'slice has_strains', 'concise' => 'Resequencing Alignments' }
  ));
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


#############################################################################

sub ldview {
  my $self = shift;
  my $obj = $self->{object};

  # Set default sources
  my @sources = keys %{ $obj->species_defs->VARIATION_SOURCES || {} } ;
  my $default_source = $obj->get_source("default");
  my $view_config = $obj->get_viewconfig();
  my $restore_default = 1;

  $self->update_configs_from_parameter( 'bottom', 'ldview', 'LD_population' );
  foreach my $source ( @sources ) {
    $restore_default = 0 if $view_config->get(lc("opt_$source") ) eq 'on';
 }

if( $restore_default && !$obj->param('bottom') ) { # if no spp sources are on
   foreach my $source ( @sources ) {
     my $switch;
     if ($default_source) {
       $switch = $source eq $default_source ? 'on' : 'off' ;
     }
     else {
       $switch = 'on';
     }
     $view_config->set(lc("opt_$source"), $switch, 1);
   }
 }

  $self->update_configs_from_parameter( 'bottom', 'ldview', 'LD_population' );

  my ($pops_on, $pops_off) = $obj->current_pop_name;
  map { $view_config->set("opt_pop_$_", 'off', 1); } @$pops_off;
  map { $view_config->set("opt_pop_$_", 'on', 1); } @$pops_on;
#  $view_config->save;


 ## This should be moved to the Location::Object module I think....
  $obj->alternative_object_from_factory( 'SNP' )  if $obj->param('snp');
  if( $obj->param('gene') ) {
    $obj->alternative_object_from_factory( 'Gene' );
    if( (@{$obj->__data->{'objects'}||[]}) && !@{ $obj->__data->{'gene'}||[]} ) {
      $obj->param('db',   $obj->__data->{'objects'}->[0]{'db'}   );
      $obj->param('gene', $obj->__data->{'objects'}->[0]{'gene'} );
      $obj->alternative_object_from_factory( 'Gene' );
    }
  }
  $obj->clear_problems();
  my $params= {
    'snp'    => $obj->param('snp'),
    'gene'   => $obj->param('gene'),
 #   'pop'    => $pops_on,
    'w'      => $obj->length,
    'c'      => $obj->seq_region_name.':'.$obj->centrepoint,
    'source' => $obj->param('source'),
    'h'      => $obj->highlights_string,
  } ;

  # Description : prints a two col table with info abou the LD ---------------
  if (
  my $info_panel = $self->new_panel( 'Information',
    'code'    => "info#",
    'caption' => 'Linkage disequilibrium report: [[object->type]] [[object->name]]'
				   )) {

    $info_panel->add_components(qw(
    focus                EnsEMBL::Web::Component::LD::focus
    prediction_method    EnsEMBL::Web::Component::LD::prediction_method
    population_info      EnsEMBL::Web::Component::LD::population_info
				  ));
    $self->{page}->content->add_panel( $info_panel );
  }

  # Multiple mappings ------------------------------------------------------
  my $snp = $obj->__data->{'snp'}->[0];
  if ($snp) {
    my $mappings = $snp->variation_feature_mapping;
    my $multi_hits = keys %$mappings == 1 ? 0 : 1;

    if ($multi_hits){
      if (
	  my $mapping_panel = $self->new_panel('SpreadSheet',
     'code'    => "mappings $self->{flag}",
     'caption' => "SNP ". $snp->name." is currently mapped to the following genomic locations:",
     'params'  => $params,
     'status'  => 'panel_mappings',
     'null_data' => '<p>This SNP cannot be mapped to the current assembly.</p>'
				       )) {
	$mapping_panel->add_components( qw(mappings EnsEMBL::Web::Component::LD::mappings) );
	$self->{page}->content->add_panel( $mapping_panel );
      }
    }
  }

  # Neighbourhood image -------------------------------------------------------
  ## Now create the image panel
  my $context = $obj->seq_region_type_and_name ." ".
    $obj->thousandify( $obj->seq_region_start );

  if (
      my $image_panel = $self->new_panel( 'Image',
     'code'    => "image_#",
     'caption' => "Context - $context",
     'status'  => 'panel_image',
     'params'  => $params,
					)) {

    if ( $obj->seq_region_type ) {
      # Store any input from Form into the 'ldview' graphic config..
      if( $obj->param( 'bottom' ) ) {
	my $wuc = $obj->image_config_hash( 'ldview' );
	$wuc->update_config_from_parameter( $obj->param('bottom') );
      }

      ## Initialize the javascript for the zmenus and dropdown menus
      $self->initialize_zmenu_javascript;
      $self->initialize_ddmenu_javascript;
      $image_panel->add_components(qw(
    menu  EnsEMBL::Web::Component::LD::ldview_image_menu
    nav   EnsEMBL::Web::Component::Location::ldview_nav
    image EnsEMBL::Web::Component::LD::ldview_image
				     ));
    }
    else {
      $image_panel->add_components(qw(
    EnsEMBL::Web::Component::LD::ldview_noimage
				     ));
    }
    $self->{page}->content->add_panel( $image_panel );
  }

  # Form ---------------------------------------------------------------------
  if (
      my $form_panel = $self->new_panel("",
    'code'    => "info$self->{flag}",
    'caption' => "Dump data",
    'status'  => 'panel_options',
    'params'  => $params,
				       )) {
    $form_panel->add_components(qw(
    options  EnsEMBL::Web::Component::LD::options
				  ));


    # finally, add the complete panel to the page object
    $self->{page}->content->add_panel( $form_panel );
  }
}


###############################################################################

sub ldtableview {

  ### Returns nothing

  my $self = shift;
  my $object = $self->{object};
  $object->alternative_object_from_factory( 'SNP' )  if $object->param('snp');
  if( $object->param('gene') ) {
    $object->alternative_object_from_factory( 'Gene' );
    if( (@{$object->__data->{'objects'}||[]}) && !@{ $object->__data->{'gene'}||[]} ) {
      $object->param('db',   $object->__data->{'objects'}->[0]{'db'}   );
      $object->param('gene', $object->__data->{'objects'}->[0]{'gene'} );
      $object->alternative_object_from_factory( 'Gene' );
    }
  }
  $object->clear_problems();

 # Description : HTML table of LD values ------------------------------------
  if (
    my $ld_panel = $self->new_panel('',
    'code'    => "info$self->{flag}",
    'caption' => 'Pairwise linkage disequilibrium values',
				   )) {

    if ($self->{object}->param('dump') eq 'ashtml') {
      $ld_panel->add_components(qw(
    html_lddata        EnsEMBL::Web::Component::LDtable::html_lddata
				  ));
    }
    elsif ($self->{object}->param('dump') eq 'astext') {
      $ld_panel->add_components(qw(
    text_lddata        EnsEMBL::Web::Component::LDtable::text_lddata
				  ));
    }
    elsif ($self->{object}->param('dump') eq 'asexcel') {
#warn "ADDING... el_ldd";
      $ld_panel->add_components(qw(
    excel_lddata        EnsEMBL::Web::Component::LDtable::excel_lddata
				  ));
    }
    elsif ($self->{object}->param('dump') eq 'ashaploview') {
      $ld_panel->add_components(qw(
    text_haploview        EnsEMBL::Web::Component::LDtable::haploview_dump
				  ));
    }
    $self->{page}->content->add_panel( $ld_panel );
  }
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
