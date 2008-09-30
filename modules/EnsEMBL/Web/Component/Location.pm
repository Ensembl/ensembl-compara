package EnsEMBL::Web::Component::Location;

use EnsEMBL::Web::Component;
use Data::Bio::Text::FeatureParser;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::File::Text;
use CGI qw(escape);
use Data::Dumper;
our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;
no warnings "uninitialized";

use POSIX qw(floor ceil);

sub default_otherspecies {
  ## Needs moving to viewconfig so we don't have to work it out each time
  my $self = shift;
  my $sd = $self->object->species_defs;
  my %synteny = $sd->multi('DATABASE_COMPARA', 'SYNTENY');
  my @has_synteny = sort keys %synteny;
  my $sp;

  ## Set default as primary species, if available
  unless ($ENV{'ENSEMBL_SPECIES'} eq $sd->ENSEMBL_PRIMARY_SPECIES) {
    foreach my $sp (@has_synteny) {
      if ($sp eq $sd->ENSEMBL_PRIMARY_SPECIES) {
        return $sp;
      }
    }
  }

  ## Set default as secondary species, if primary not available
  unless ($ENV{'ENSEMBL_SPECIES'} eq $sd->ENSEMBL_SECONDARY_SPECIES) {
    foreach $sp (@has_synteny) {
      if ($sp eq $sd->ENSEMBL_SECONDARY_SPECIES) {
        return $sp;
      }
    }
  }

  ## otherwise choose first in list
  return $has_synteny[0];
}

sub chr_list {
### Method to create an array of chromosome names for use in dropdown lists
  my $self = shift;
  my @all_chr = @{$self->object->species_defs->ENSEMBL_CHROMOSOMES};
  my @chrs;
  foreach my $next (@all_chr) {
    push @chrs, {'name'=>$next, 'value'=>$next} ;
  }
  return @chrs;
}


sub name {
  my($panel,$object) = @_;
  (my $DATE = $object->species_defs->ARCHIVE_VERSION ) =~ s/(\d+)/ $1/;
  $panel->add_row( 'Site summary', qq(<p>@{[$object->species_defs->ENSEMBL_SITETYPE]} - $DATE</p>) );
  return 1;
}

sub create_userdata_pointers {
  my ($self, $image, $userdata) = @_;
  my $object = $self->object;

  my $file = new EnsEMBL::Web::File::Text($object->species_defs);
  my $data = $file->retrieve($userdata->{'filename'});
  my $format  = $userdata->{'format'};

  my $parser = Data::Bio::Text::FeatureParser->new();
  $parser->parse($data, $format);

  my $zmenu_config = {
    'caption' => 'features',
    'entries' => ['userdata'],
  };

  ## create image with parsed data
  my $pointer_set = $image->add_pointers(
      $object,
          {
          'config_name'   => 'Vkar2view',
          'parser'        => $parser,
          'zmenu_config'  => $zmenu_config,
          'color'         => $object->param("col")
                               || 'red',
          'style'         => $object->param("style")
                               || 'lharrow',
          }
  );

  return $pointer_set;
}

sub multi_ideogram {
  my( $panel, $object ) = @_;
  my $counter = 0;
  my @species = $object->species_list();
## Start the box containing the image
  $panel->printf(
    qq(<div style="width: %dpx; border: solid 1px %s" class="autocenter navbox">),
    $object->param('image_width'), $panel->option( 'red_edge' ) ? 'red' : 'black'  
  );
  foreach my $loc ( $object->Locations ) {
## Foreach of the "species slices, draw an image of the slice within this box!  
    my $slice = $object->database('core', $loc->real_species )->get_SliceAdaptor()->fetch_by_region(
      $loc->seq_region_type, $loc->seq_region_name, 1, $loc->seq_region_length, 1
    );
    my $wuc = $object->image_config_hash( "chromosome_$counter", "chromosome" );
       $wuc->set_width(       $loc->param('image_width') - 2 );
       $wuc->set_species(     $loc->real_species );
       $wuc->container_width( $loc->seq_region_length );
       $wuc->set_width(       $object->param('image_width') - 2 );
       $wuc->{ 'no_image_frame' } = 1;
       $wuc->{ 'multi' }  = 1;
    red_box( $wuc, @{$panel->option("red_box_$counter")} ) if $panel->option( "red_box_$counter" );
    my $image    = $object->new_image( $slice, $wuc, $object->highlights );
       $image->set_button( 'form',
         'name'   => 'click',
         'extra'  => "_ideo_$counter",
         'title'  => 'Click to centre display',
         'id'     => "click_ideo_$counter",
         'URL'    => "/@{[$loc->real_species]}/@{[$object->script]}",
         'hidden' => {
           'click_left'        => int( $wuc->transform->{'translatex'} ),
           'click_right'       => int( $wuc->transform->{'scalex'} * $loc->seq_region_length +  
                                  int( $wuc->transform->{'translatex'} ) ),
           'seq_region_strand' => $loc->seq_region_strand,
           'seq_region_left'   => 1,
           'seq_region_right'  => $loc->seq_region_length,
           'seq_region_width'  => $loc->seq_region_end - $loc->seq_region_start + 1,
           'seq_region_name'   => $loc->seq_region_name,
           'h'                 => $loc->highlights_string,
           multi_species_list( $object, $loc->real_species )
         }
       );
    $panel->print( $image->render );
    $counter++;
  }
## Finish off bounding box around panel...
  $panel->print('</div>');
}

sub multi_top {
  my( $panel, $object ) = @_;
  my $counter = 0;
  $panel->printf( qq(<div style="width: %dpx; border: solid 1px %s" class="autocenter navbox">),
                  $object->param('image_width'), $panel->option( 'red_edge' ) ? 'red' : 'black'  );
  my @species = $object->species_list();
  foreach my $loc ( $object->Locations ) {
    my $slice = $object->database( 'core', $loc->real_species )->get_SliceAdaptor()->fetch_by_region(
      $loc->seq_region_type, $loc->seq_region_name, $panel->option( "start_$counter" ), $panel->option( "end_$counter" ), $loc->seq_region_strand
    );
    my $wuc = $object->image_config_hash( "contigviewtop_$counter", "contigviewtop" );
       $wuc->set_species( $loc->real_species );
       $wuc->set_width(   $loc->param('image_width') - 2 );
       $wuc->{ 'no_image_frame' } = 1;
       $wuc->set( 'gene_legend', 'on', 'off' );
       $wuc->set( 'marker', 'on', 'off' );
       $wuc->{'multi'}  = 1;
       red_box( $wuc, @{$panel->option("red_box_$counter")} ) if $panel->option( "red_box_$counter" );
    my $lower_width = $loc->seq_region_end-$loc->seq_region_start+1;
       $wuc->container_width( $slice->length );
    my $image = $object->new_image( $slice, $wuc, $object->highlights );
       $image->set_button( 'form',
         'name'   => 'click',
         'extra'  => "_top_$counter",
         'id'     => "click_top_$counter",
         'title'  => 'Click to centre display',
         'URL'    => "/@{[$loc->real_species]}/@{[$object->script]}",
         'hidden' => {
           'click_left'        => int( $wuc->transform->{'translatex'} ),
           'click_right'       => int( $wuc->transform->{'scalex'} * $slice->length + int( $wuc->transform->{'translatex'} ) ),
           'seq_region_strand' => $loc->seq_region_strand,
           'seq_region_left'   => $panel->option("start_$counter"),
           'seq_region_right'  => $panel->option("end_$counter"),
           'seq_region_width'  => $lower_width < 1e6 ? $lower_width : 1e6,
           'seq_region_name'   => $loc->seq_region_name,
           'h'                 => $loc->highlights_string,
           multi_species_list( $object, $loc->real_species )
         }
       );
    $panel->print( $image->render );
    $counter++;
  }
  $panel->print('</div>');
}

sub multi_bottom {
  my( $panel, $object ) = @_;
  my $counter = 0;
  my( $primary,@secondary ) = ($object->Locations);
  my $primary_slice         = $primary->[1]{'_object'};
  my $array = [];
  my @other_slices = map { {'location' => $_, 'ori' => $_->seq_region_strand, 'species' => $_->real_species} } @secondary;
  my $base_URL = "/".$primary->real_species."/".$object->script."?".$object->generate_query_url;
  if( @secondary > 1 ) { ## We do S_0, P, S_1, P, S_2 .... 
    my $C = 1;
    push_secondary( $array, shift @secondary, $C );
    while( my $T = shift @secondary ) {
      $C++;
      push_primary( $array, $primary );
      push_secondary( $array, $T, $C );
    }
  } else {
    push_primary( $array, $primary );
    push_secondary( $array, $secondary[0], 1 ) if @secondary;
  }
  my $slices = (@$array)/2;
  my %flags;
  foreach my $K (qw(match join_match hcr join_hcr tblat join_tblat group_match group_hcr group_tblat)) {
    $flags{ $K } = $object->param( "opt_$K" ) eq 'on';
  }
  foreach( my $i = 0; $i< $slices; $i++ ) {
    my $config    = $array->[$i*2+1];
       $config->{'base_url'} = $base_URL;
       $config->set( '_settings', 'URL',   $base_URL.";bottom=%7Cbump_", 1 );
    my $prev_conf = $i ? $array->[$i*2-1] : undef;
    my $next_conf = $i<$slices-1 ? $array->[$i*2+3] : undef;
    my $previous_species = $prev_conf ? $prev_conf->{'species'} : undef;
    my $next_species     = $next_conf ? $next_conf->{'species'} : undef;
       $config->{'previous_species'}   = $previous_species;
       $config->{'next_species'}       = $next_species;
       $config->{'slice_id'}           = $i;
       $config->{'other_slices'}       = \@other_slices;
       $config->{'primary_slice'}      = $primary_slice; 
    if( $previous_species && $next_species eq $previous_species ) {
      if( $flags{'match'} ) {
        foreach(qw( BLASTZ_RAW PHUSION_BLASTN BLASTZ_NET BLASTZ_GROUP BLASTZ_RECIP_NET BLASTZ_CHAIN) ) {
          my $K = lc($previous_species)."_".lc($_)."_match";
		  $config->set( $K, "on", "on" );
          $config->set( $K, "str", "x" );
          $config->set( $K, "join", 1 ) if $flags{ 'join_match' };
          $config->set( $K, "compact", $flags{ 'group_match' } ? 0 : 1 );
        }
      }
      if( $flags{'hcr'} ) {
        foreach(qw(PHUSION_BLASTN_TIGHT BLASTZ_NET_TIGHT BLASTZ_GROUP_TIGHT)) {
          my $K = lc($previous_species)."_".lc($_)."_match";
          $config->set( $K, "on", "on" );
          $config->set( $K, "str", "x" );
          $config->set( $K, "join", 1 ) if $flags{ 'join_hcr' };
          $config->set( $K, "compact", $flags{ 'group_hcr' } ? 0 : 1 );
        }
      }
      if( $flags{'tblat'} ) {
        foreach( 'TRANSLATED_BLAT' ) {
          my $K = lc($previous_species)."_".lc($_)."_match";
          $config->set( $K, "on", "on" );
          $config->set( $K, "str", "x" );
          $config->set( $K, "join", 1 ) if $flags{ 'join_tblat' };
          $config->set( $K, "compact", $flags{ 'group_tblat' } ? 0 : 1 );
        }
      }
    } else {
      if( $previous_species ) {
        if( $flags{'match'} ) {
          foreach(qw( BLASTZ_RAW PHUSION_BLASTN BLASTZ_NET BLASTZ_GROUP BLASTZ_RECIP_NET BLASTZ_CHAIN) ) {
            my $K = lc($previous_species)."_".lc($_)."_match";
            $config->set( $K, "on", "on" );
            $config->set( $K, "str", "f" );
            $config->set( $K, "join", 1 ) if $flags{ 'join_match' };
            $config->set( $K, "compact", $flags{ 'group_match' } ? 0 : 1 );
          }
        }
        if( $flags{'hcr'} ) {
          foreach(qw(PHUSION_BLASTN_TIGHT BLASTZ_NET_TIGHT BLASTZ_GROUP_TIGHT)) {
            my $K = lc($previous_species)."_".lc($_)."_match";
            $config->set( $K, "on", "on" );
            $config->set( $K, "str", "f" );
            $config->set( $K, "join", 1 ) if $flags{ 'join_hcr' };
            $config->set( $K, "compact", $flags{ 'group_hcr' } ? 0 : 1 );
          }
        }
        if( $flags{'tblat'} ) {
          foreach( 'TRANSLATED_BLAT' ) {
            my $K = lc($previous_species)."_".lc($_)."_match";
            $config->set( $K, "on", "on" );
            $config->set( $K, "str", "f" );
            $config->set( $K, "join", 1 ) if $flags{ 'join_tblat' };
            $config->set( $K, "compact", $flags{ 'group_tblat' } ? 0 : 1 );
          }
        }
      }
      if( $next_species ) {
        if( $flags{'match'} ) {
          foreach(qw( BLASTZ_RAW PHUSION_BLASTN BLASTZ_NET BLASTZ_GROUP BLASTZ_RECIP_NET BLASTZ_CHAIN) ) {
            my $K = lc($next_species)."_".lc($_)."_match";
            $config->set( $K, "on", "on" );
            $config->set( $K, "str", "r" );
            $config->set( $K, "join", 1 ) if $flags{ 'join_match' };
            $config->set( $K, "compact", $flags{ 'group_match' } ? 0 : 1 );
          }
        }
        if( $flags{'hcr'} ) {
          foreach(qw(PHUSION_BLASTN_TIGHT BLASTZ_NET_TIGHT BLASTZ_GROUP_TIGHT )) {
            my $K = lc($next_species)."_".lc($_)."_match";
            $config->set( $K, "on", "on" );
            $config->set( $K, "str", "r" );
            $config->set( $K, "join", 1 ) if $flags{ 'join_hcr' };
            $config->set( $K, "compact", $flags{ 'group_hcr' } ? 0 : 1 );
          }
        }
        if( $flags{'tblat'} ) {
          foreach( 'TRANSLATED_BLAT' ) {
            my $K = lc($next_species)."_".lc($_)."_match";
            $config->set( $K, "on", "on" );
            $config->set( $K, "str", "r" );
            $config->set( $K, "join", 1 ) if $flags{ 'join_tblat' };
            $config->set( $K, "compact", $flags{ 'group_tblat' } ? 0 : 1 );
          }
        }
      }
    }
  }
  $array->[1]->{'image_frame_colour'} = 'red' if $panel->option( 'red_edge' ) eq 'yes';
  my $image = $object->new_image( $array, $object->highlights );
  $image->imagemap = 'yes';
  $panel->print( $image->render );
}

sub push_primary {
  my( $array, $loc ) = @_;
  my $P = @$array;
  my $wuc = $loc->image_config_hash( "thjviewbottom_$P", "thjviewbottom" );
     $wuc->set_species(     $loc->real_species );
     $wuc->set_width(       $loc->param('image_width') );
     $wuc->container_width( $loc->length );
     $wuc->mult;
     $wuc->{'multi'}  = 1;
     $wuc->{'compara'} = 'primary';
     $wuc->{'slice_number'}=0;
     $loc->slice->{web_species} = $loc->real_species;
  push @$array, $loc->slice, $wuc;
}

sub push_secondary {
  my( $array, $loc, $slice_no ) = @_;
  my $P = @$array;
  my $wuc = $loc->image_config_hash( "thjviewbottom_$P", "thjviewbottom" );
     $wuc->set_species(     $loc->real_species );
     $wuc->set_width(       $loc->param('image_width') );
     $wuc->container_width( $loc->length );
     $wuc->mult;
     $wuc->{'multi'}   = 1;
     $wuc->{'compara'} = 'secondary';
     $wuc->{'slice_number'} = $slice_no;
     $loc->slice->{web_species} = $loc->real_species;
  push @$array, $loc->slice, $wuc;
}

sub ideogram_old {
  my($panel, $object) = @_;
  my $slice = $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, 1, $object->seq_region_length, 1
  );
  my $wuc = $object->image_config_hash( 'chromosome' );
     $wuc->container_width( $object->seq_region_length );
     $wuc->set_width( $object->param('image_width') );
     $wuc->{'image_frame_colour'} = 'red' if $panel->option( 'red_edge' ) eq 'yes';
  red_box( $wuc, @{$panel->option('red_box')} ) if $panel->option( 'red_box' );
  my $image    = $object->new_image( $slice, $wuc );
     $image->set_button( 'form',
       'name'   => 'click',
       'extra'  => '_ideo',
       'id'     => 'click_ideo',
       'URL'    => "/@{[$object->species]}/@{[$object->script]}",
       'title'  => 'Click to centre display',
       'hidden' => {
         'click_left'        => int( $wuc->transform->{'translatex'} ),
         'click_right'       => int( $wuc->transform->{'scalex'} * $object->seq_region_length + int( $wuc->transform->{'translatex'} ) ),
         'seq_region_strand' => $object->seq_region_strand,
         'seq_region_left'   => 1,
         'seq_region_right'  => $object->seq_region_length,
         'seq_region_width'  => $object->seq_region_end-$object->seq_region_start + 1,
         'seq_region_name'   => $object->seq_region_name,
         'h'                 => $object->highlights_string,
       }
     );
  $panel->print( $image->render );
  return 1;
}

sub ideogram {
  my($panel, $object) = @_;
  my $slice = $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, 1, $object->seq_region_length, 1
  );
  my $wuc = $object->image_config_hash( 'chromosome' );
     $wuc->container_width( $object->seq_region_length );
     $wuc->set_width( $object->param('image_width') );
     $wuc->{'image_frame_colour'} = 'red' if $panel->option( 'red_edge' ) eq 'yes';
  red_box( $wuc, @{$panel->option('red_box')} ) if $panel->option( 'red_box' );

  my $image    = $object->new_image( $slice, $wuc );
  my $click_left  = int( $wuc->transform->{'translatex'} );
  my $click_right = int( $wuc->transform->{'scalex'} * $object->seq_region_length + int( $wuc->transform->{'translatex'} ) );
  my $panel_no = ++ $object->__data->{'_cv_panel_no'};
     $image->{'panel_number'} = $panel_no;
     $image->cacheable   = 'yes';
     $image->image_type  = 'ideogram';
     $image->image_name  = ($object->param('image_width')).'-'.$ENV{'ENSEMBL_SPECIES'}.'-'.$object->seq_region_name;
     $image->set_button( 'drag', 'panel_number' => $panel_no, 'title' => 'Click or drag to centre display' );
  #$panel->print( '<div id="debug" style="z-index: 50; position:absolute; top: 0px; left: 0px; width:300px; height:300px">DEBUG</div>')
  $panel->print( $image->render );
  $object->__data->{'_cv_parameter_hash'}{ "p_${panel_no}_px_start" } = $click_left,
  $object->__data->{'_cv_parameter_hash'}{ "p_${panel_no}_px_end"   } = $click_right,
  $object->__data->{'_cv_parameter_hash'}{ "p_${panel_no}_bp_start" } = 1;
  $object->__data->{'_cv_parameter_hash'}{ "p_${panel_no}_bp_end"   } = $object->seq_region_length;
  $object->__data->{'_cv_parameter_hash'}{ "p_${panel_no}_visible"  } = 1;
  $object->__data->{'_cv_parameter_hash'}{ "p_${panel_no}_flag"     } = 'cv';
  $object->__data->{'_cv_parameter_hash'}{ "p_${panel_no}_URL"      } = "/$ENV{ENSEMBL_SPECIES}/$ENV{ENSEMBL_SCRIPT}?c=[[s]]:[[c]];w=[[w]]";
  return 1;
}

sub alignsliceviewbottom_text {
  my($panel, $object) = @_;
  my $width = $object->param('image_width') - 2;
  $panel->print( qq(<div style="background-color: #ffffe7; width: ${width}px; border: solid 1px black;" class="print_hide_block autocenter">
    <p style="padding: 2px; margin: 0px;">
      The region you are trying to display is too large. To zoom into a
      viewable region use the zoom buttons above - or click on the top
      display to centre and zoom the image
    </p>
  </div>) 
  );
  return 0;
}

sub multi_species_list { 
	my( $object,$species ) = @_;
	$species ||= $object->species;
	my %species_hash;
	my %self_config = $object->species_defs->multiX('VEGA_COMPARA_CONF');
	#if we have a self-compara (ie Vega) then get further details
	if ( %self_config ) {
		my @details = $object->species_and_seq_region_list;
		my $C = 1;
		my ($type,$srname) = split / / , $object->seq_region_type_and_name;
		foreach my $assoc (@details) {
			my ($sp,$sr) = split /:/, $assoc;
			$species_hash{ 's'.$C } = $object->species_defs->ENSEMBL_SHORTEST_ALIAS->{$sp};
			$species_hash{ 'sr'.$C++ } = $sr;
		}
	} else {
		#otherwise just get species names
		my %species_flag = ( $species => 1 );
		my $C = 1;
		foreach ($object->species_list()) {
			next if $species_flag{$_};
			$species_flag{ $_       } = 1;
			$species_hash{ 's'.$C++ } = $object->species_defs->ENSEMBL_SHORTEST_ALIAS->{$_};
		}
	}
	return %species_hash;
}



sub ldview_nav           {
  my ($pops_on, $pops_off ) = $_[1]->current_pop_name;
  my $pop;
  map { $pop .= "opt_pop_$_:on;" } @$pops_on;
  map { $pop .= "opt_pop_$_:off;" } @$pops_off;

  return bottom_nav( @_, 'ldview',   {
    'snp'    => $_[1]->param('snp')    || undef,
    'gene'   => $_[1]->param('gene')   || undef,
    'bottom' => $pop                   || undef,
    'source' => $_[1]->param('source'),
    'h'      => $_[1]->highlights_string || undef,
  } );    
}

sub alignsliceviewbottom_menu {  
    my($panel, $object ) = @_;
    my $configname = 'alignsliceviewbottom';

    my @menu_items = qw(Features AlignCompara Repeats Options ASExport ImageSize);
    return 0;
}

sub multi_bottom_menu {
  my($panel, $object ) = @_;
  return 0;
}

sub misc_set {
  my( $panel, $object ) =@_;
  my $T = $panel->form( 'misc_set' );
  $panel->print( $T->render ) if $T;
  return 1;
}

sub misc_set_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'misc_set', "/@{[$object->species]}/miscsetview", 'get' );
  my $formats = [
    { 'value' =>'HTML' , 'name' => 'HTML' },
    { 'value' =>'Text' , 'name' => 'Text (Tab separated values)' },
  ];

  my $miscsets = [];
  my $misc_set_keys = $object->species_defs->EXPORTABLE_MISC_SETS || [];

  my $misc_sets = $object->get_all_misc_sets();
  foreach my $T ( @$misc_set_keys ) {
    push @$miscsets , { 'value' => $T, 'name' => $misc_sets->{$T}->name } if $misc_sets->{$T};
  }
  return undef unless @$miscsets;
#warn "GENERATING FORM";

  my $output_types = [
   { 'value' => 'set',    'name' => "Features on this chromosome" },
   { 'value' => 'slice',  'name' => "Features in this region" },
   { 'value' => 'all',    'name' => "All features in set" }
  ];

  $form->add_element( 'type' => 'DropDown', 'select' => 'select',
    'label'    => 'Select Set of features to render',
    'firstline' => '=select=',
    'requried' => 'yes', 'name' => 'set',
    'value'    => $object->param('set'),
    'values'   => $miscsets
  ); 
  $form->add_element( 'type' => 'DropDown', 'select' => 'select',
    'label'    => 'Output format',
    'required' => 'yes', 'name' => '_format', 
    'values'   => $formats,
    'value'    => $object->param('_format') || 'HTML'
  );
  $form->add_element( 'type' => 'DropDown', 'select' => 'select',
    'label'    => 'Select type to export',
    'firstline' => '=select=',
    'required' => 'yes', 'name' => 'dump',
    'values'   => $output_types,
    'value'    => $object->param('dump')
  );
  $form->add_element( 'type' => 'Hidden', 'name' => 'l',
    'value' => $object->seq_region_name.':'.$object->seq_region_start.'-'.$object->seq_region_end );
  $form->add_element( 'type'  => 'Submit', 'value' => 'Export' );
  return $form;
}


sub alignsliceviewbottom {
    my($panel, $object) = @_;
    my $scaling = $object->species_defs->ENSEMBL_GENOME_SIZE || 1;
    my $max_length = $scaling * 1e6;
    my $slice = $object->database('core')->get_SliceAdaptor()
    ->fetch_by_region( $object->seq_region_type, $object->seq_region_name, $object->seq_region_start, $object->seq_region_end, 1 );

    my $wuc = $object->image_config_hash( 'alignsliceviewbottom_0', 'alignsliceviewbottom' );

    my $zwa = $object->param('zoom_width');

    my $species = $object->species;
    my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, "core", "Slice");

    my $query_slice= $query_slice_adaptor->fetch_by_region($slice->coord_system_name, $slice->seq_region_name, $slice->start, $slice->end);

    my $comparadb = $object->database('compara');
    my $mlss_adaptor = $comparadb->get_adaptor("MethodLinkSpeciesSet");

    my $aID = $wuc->get("alignslice", "id");
    my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($aID); 

# With every new release the compara team update the alignment IDs
# It would be much better if we had something permanent to refer to, but as for 
# now we have to check that the selected alignment is still in the compara database.
# If it's not we just choose the first alignment that we can find for this species

    if (! $method_link_species_set) {
    my %alignments = $object->species_defs->multiX('ALIGNMENTS');

    foreach my $a (sort keys %alignments) {
      if ($alignments{$a}->{'species'}->{$species}) {
        $aID = $a;
        $wuc->get("alignslice", "id", $aID, 1);
#        $wuc->save;
        $method_link_species_set = $mlss_adaptor->fetch_by_dbID($aID); 
        last;
      }
    }
    }

    my @selected_species = @{$wuc->get("alignslice", "species") || []};
    unshift @selected_species, $object->species if (scalar(@selected_species));

    my $asa = $comparadb->get_adaptor("AlignSlice" );
    my $align_slice = $asa->fetch_by_Slice_MethodLinkSpeciesSet($query_slice, $method_link_species_set, "expanded", "restrict" );

    $object->Obj->{_align_slice} = $align_slice;

    my @ARRAY;
    my $url = $wuc->get('_settings','URL');
    my $align = $wuc->get('alignslice','align');
    my $cmpstr = 'primary';
    my $t1 = $wuc->get('ensembl_transcript','compact');
    my $t2 = $wuc->get('evega_transcript','compact');
    my $t3 = $wuc->get('variation','on');
    my $t4 = $wuc->get('alignslice','constrained_elements');
    my $id = 0;

    my $as_slices = $align_slice->get_all_Slices(@selected_species);
    ## $num represent the total number of tracks and is used to "close" the view.
    ## There might be more than one track per species.
    my $num = scalar(@$as_slices);

    add_repeat_tracks( $object, $wuc );

    foreach my $as (@{$as_slices}) {
    (my $vsp = $as->genome_db->name) =~ s/ /_/g;
    $id ++;
    my $CONF = $object->image_config_hash( "alignsliceviewbottom_$id", "alignsliceviewbottom"  );
    $CONF->{'align_slice'}  = 1;
    $CONF->set('scalebar', 'label', $vsp);
    $CONF->set('alignslice', 'align', $align);
    $CONF->set_species($vsp);
    $CONF->set('_settings','URL',$url,1);
    $CONF->set('ensembl_transcript', 'compact', $t1, 1);
    $CONF->set('evega_transcript', 'compact', $t2, 1);
    $CONF->set('variation', 'on', $t3, 1 );
    $CONF->set('constrained_elements', 'on', $t4, 1 );
    $CONF->container_width( $as->length );
    $CONF->{'_managers'}{'sub_repeat'} = $wuc->{'_managers'}{'sub_repeat'};
    $CONF->{_object} = $object;
    $CONF->set_width($object->param('image_width') );
    $CONF->set( '_settings', 'URL',   this_link($object).";bottom=%7Cbump_", 1);
    $CONF->{'image_frame_colour'} = 'red' if $panel->option( 'red_edge' ) eq 'yes';

    red_box( $CONF, @{$panel->option('red_box')} ) if $panel->option( 'red_box' );

    $as->{species} = $as->genome_db->name;
    $as->{compara} = $cmpstr;
    $as->{web_species} = $vsp;
    $as->{__type__} = 'alignslice';

    if ($id == $num) {
        $as->{compara} = 'final' if ($cmpstr ne 'primary');
    }

    push @ARRAY, $as, $CONF;
    $cmpstr = 'secondary';
    
    }

    my $image = $object->new_image( \@ARRAY, $object->highlights );
    $image->imagemap = 'yes';
    $panel->print( $image->render );
    return 0;
}

 sub alignsliceviewzoom_nav {
     my($panel, $object) = @_;
     my $wid = $panel->option('end') - $panel->option('start') + 1;
     my %additional_hidden_values = ( 'h' => $object->highlights_string );
     my $hidden_fields_string = join '', map { qq(<input type="input" name="$_" value="$additional_hidden_values{$_}" />) } keys %additional_hidden_values;
     my $hidden_fields_URL    = join ';', map { qq($_=$additional_hidden_values{$_}) } keys %additional_hidden_values;


     my $zoom_h = $wid > 25 ? this_link( $object, ';zoom_width='.($wid-25), $hidden_fields_URL ) : '#';
     my $zoom_ii  = $wid < 150 ? this_link( $object, ';zoom_width='.($wid+25), $hidden_fields_URL ): '#';
     my $pan_left_1_win  = this_link_offset( $object, -0.8 * $wid );
     my $pan_right_1_win = this_link_offset( $object,  0.8 * $wid );

     my $wuc = $object->image_config_hash( 'alignsliceviewzoom', 'alignsliceviewbottom' );
     my $selected;
     my $width = $object->param('image_width');
     my %zoomgifs = %{$wuc->get('_settings','align_zoom_gifs')||{}};
     my $zoom_HTML;
     for my $zoom (sort keys %zoomgifs){
       my $zoombp = $zoomgifs{$zoom};
       if( ($wid <= ($zoombp+2) || $zoom eq 'zoom6' )&& !$selected ){
           $zoom .= "on";
           $selected = "1";
     }
     my $zoomurl =  this_link( $object, ";zoom_width=$zoombp" );
     my $unit_str = $zoombp;
     $zoom_HTML.=qq(<a href="$zoomurl"><img src="/img/buttons/$zoom.gif"
      title="show $unit_str in zoom" alt="show $unit_str in zoom" class="cv_zoomimg" /></a>);
   }

   my $output = qq(
   <table style="border:0; margin:0; padding: 0; width: @{[$width-2]}px"><tr><td class="middle">
   <a href="$pan_left_1_win" class="cv-button">&lt; Window</a>
   </td><td class="middle center">
   <a href="$zoom_h" class="cv_plusminus">+</a>
   </td><td class="middle center">
   ${zoom_HTML}
   </td><td class="middle center">
   <a href="$zoom_ii" class="cv_plusminus">&#8211;</a>
   </td><td class="right middle">
   <a href="$pan_right_1_win" class="cv-button">Window &gt;</a>
   </td></tr></table>);
   $panel->print( nav_box_frame( $output, $width ) );
   return 0;
 }

sub alignsliceviewzoom {
    my($panel, $object) = @_;

    my $species = $ENV{ENSEMBL_SPECIES};
    my $gstart = $panel->option('start');
    my $gend = $panel->option('end');
    my $align_slice;
    my $fcstart = 0;
    my $fcend = $gend;

    my $wuc = $object->image_config_hash( 'alignsliceviewbottom' );
    my $aID = $wuc->get("alignslice", "id");
    my @selected_species = @{$wuc->get("alignslice", "species") || []};
    unshift @selected_species, $object->species if (@selected_species);

    if ($align_slice = $object->Obj->{_align_slice}) {
    my $pAlignSlice = $align_slice->get_all_Slices($species)->[0];
    my $gc = $align_slice->reference_Slice->start;
    my $cigar_line = $pAlignSlice->get_cigar_line();
    my @inters = split (/([MDG])/, $cigar_line);
    my ($ms, $ds);
    my $fc = 0;
    while (@inters) {
        $ms = (shift (@inters) || 1);
        my $mtype = shift (@inters);
        
        $fc += $ms;

        if ($mtype =~ /M/) {
# Skip normal alignment and gaps in alignments
        $gc+=$ms;
        last if ($gc > $gstart);
        }
    }

    $fcstart = $fc - ($gc - $gstart);
    if ($gc < $gstart) {
        while (@inters) {
        $ms = (shift (@inters) || 1);
        my $mtype = shift (@inters);
        
        $fc += $ms;

        if ($mtype =~ /M/) {
# Skip normal alignment and gaps in alignments
            $gc+=$ms;
            last if ($gc > $gend);
        }
        }
    }
    $fcend = $fc - ($gc - $gend);
    $align_slice = $align_slice->sub_AlignSlice( $fcstart +1 , $fcend +1);
    } else {
    my $slice = $object->database('core')->get_SliceAdaptor()
        ->fetch_by_region($object->seq_region_type, $object->seq_region_name, $gstart, $gend, 1 );

    my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, "core", "Slice");
    
    my $query_slice= $query_slice_adaptor->fetch_by_region($slice->coord_system_name, $slice->seq_region_name, $slice->start, $slice->end);

    my $comparadb = $object->database('compara');
    my $mlss_adaptor = $comparadb->get_adaptor("MethodLinkSpeciesSet");
    my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($aID);

    my $asa = $comparadb->get_adaptor("AlignSlice" );
    $align_slice = $asa->fetch_by_Slice_MethodLinkSpeciesSet($query_slice, $method_link_species_set, "expanded", "restrict" );

    }

    my @SEQ = ();
    foreach my $as (@{$align_slice->get_all_Slices(@selected_species)}) {
    my $seq = $as->seq;
    my $ind = 0;
    foreach (split(//, $seq)) {
        $SEQ[$ind++]->{uc($_)} ++;
    }
    }

    my $as_slices = $align_slice->get_all_Slices(@selected_species);
    ## $num represent the total number of tracks and is used to "close" the view.
    ## There might be more than one track per species.
    my $num = scalar($as_slices) || 2;

    foreach my $nt (@SEQ) {
    $nt->{S} = join('', grep {$nt->{$_} >= $num} keys(%{$nt}));
    }

    my @ARRAY;
    my $cmpstr = 'primary';
    my $id = 0;

    foreach my $as (@$as_slices) {
    (my $vsp = $as->genome_db->name) =~ s/ /_/g;
    $id ++;
    my $wuc = $object->image_config_hash( "alignsliceviewzoom_$id", 'alignsliceviewbottom' );
    $wuc->container_width( $panel->option('end') - $panel->option('start') + 1 );
    $wuc->set_width( $object->param('image_width') );
    $wuc->set( '_settings', 'opt_empty_tracks', 'off' );
    $wuc->set( 'stranded_contig', 'on', 'off' );
    $wuc->set( 'ensembl_transcript', 'on', 'off' );
    $wuc->set( 'evega_transcript', 'on', 'off' );
    $wuc->set( 'ruler', 'on', 'off' );
    $wuc->set( 'repeat_lite', 'on', 'off' );
    $wuc->{'image_frame_colour'} = 'red' if $panel->option( 'red_edge' ) eq 'yes';
    $wuc->set( '_settings', 'URL',   this_link($object).";bottom=%7Cbump_", 1);

    $wuc->set( '_settings', 'intercontainer', 0, 1 );
    $wuc->set( 'alignment', 'on', 'on' );
    $wuc->set( 'alignscalebar', 'on', 'off' );
    $wuc->set( 'variation', 'on', 'off' );
    $wuc->{_object} = $object;
    $wuc->{'align_slice'}  = 1;
    $wuc->set('scalebar', 'label', $vsp);
    $wuc->set_species($vsp);

    $as->{alignmatch} = \@SEQ;
    $as->{exons_markup} = &exons_markup($as);
    $as->{snps_markup} = &snps_markup($as);
    if ($id == $num) {
        $as->{compara} = 'final' if ($cmpstr ne 'primary');
    }
    push @ARRAY, $as, $wuc;
    $cmpstr = 'secondary';
    }

    my $image    = $object->new_image( \@ARRAY, $object->highlights );
    $image->imagemap = 'yes';
    my $T = $image->render;
    $panel->print( $T );
    return 1;
}

sub exons_markup {
   my ($slice) = @_;

#   my @analyses = ( 'ensembl', 'pseudogene');
   my @analyses = ( 'ensembl', 'pseudogene', 'havana', 'ensembl_havana_gene' );
   my $db_alias = 'core';
   my @genes;
   foreach my $analysis( @analyses ){
       push @genes, @{ $slice->get_all_Genes($analysis, $db_alias) };
   }
   my $slice_length = length($slice->seq);
   
   my @exons;
   foreach (@genes) {
       my $tlist = $_->get_all_Transcripts();
       foreach my $t (@$tlist) {
         my $elist = $t->get_all_Exons();
         foreach my $ex (@$elist) {
#         warn("exon:".join('*', $ex->start, $ex->end, $ex->get_aligned_start, $ex->get_aligned_end, $ex->exon->start, $ex->exon->end)); 
             next if (!$ex->start);

             my ($active_start, $active_end)  = (0, 0);

# If you have questions about the code below - please send them to Javier Herrero <jherrero@ebi.ac.uk> :)

         if ($ex->strand > 0) {
         if ($ex->end <= $slice_length && $ex->exon->end - $ex->exon->start + 1  == $ex->get_aligned_end  ) {
             $active_end = 1;
         }

         
         if ($ex->get_aligned_start == 1 && $ex->start > 0) {
             $active_start = 1;
         }
         } else {
         if ($ex->end <= $slice_length && $ex->get_aligned_start == 1) {
             $active_end = 1;
         }

         if ($ex->start > 0 && $ex->exon->end - $ex->exon->start + 1  == $ex->get_aligned_end ) {
             $active_start = 1;
         }
         }

#warn("EXON:".join('*', $slice_length, $ex->start, $ex->end, $ex->get_aligned_start, $ex->get_aligned_end, $ex->exon->start, $ex->exon->end, $active_start, $active_end)); 
            push @exons, {
                 'start' => $ex->start,
                 'end' => $ex->end,
         'strand'  => $ex->strand,
                 'active_start' => $active_start,
                 'active_end' => $active_end,
                 }
         }
       }

   }

   return \@exons;
}

sub snps_markup {
     my ($slice) = @_;
     my $vf_ref = $slice->get_all_VariationFeatures();
     my @snps;

     foreach (@$vf_ref) {
       push @snps, {
           'start' => $_->start,
           'end' => $_->end,
           'strand'  => $_->strand,
           'source' => $_->source,
           'consequence_type' => $_->{consequence_type},
           'variation_name' => $_->variation_name,
           'allele_string' => $_->allele_string,
           'ambig_code' => $_->ambig_code,
           'var_class' => ($_->var_class || '-')
           } ;
    }

     return \@snps;

}
sub alignsliceviewtop {
     my($panel, $object) = @_;
     my $scaling = $object->species_defs->ENSEMBL_GENOME_SIZE || 1;

     my $slice = $object->database('core')->get_SliceAdaptor()->fetch_by_region(
     $object->seq_region_type, $object->seq_region_name, $panel->option('start'), $panel->option('end'), 1
                                                                              );
     my $wuc = $object->image_config_hash( 'alignsliceviewtop' );
     $wuc->container_width( $panel->option('end')-$panel->option('start')+1 );
     $wuc->set_width(       $object->param('image_width') );
     $wuc->{'image_frame_colour'} = 'red' if $panel->option( 'red_edge' ) eq 'yes';
     red_box( $wuc, @{$panel->option('red_box')} ) if $panel->option( 'red_box' );

    my @skeys = grep { $_ =~ /^synteny_/ } keys (%{$wuc->{general}->{alignsliceviewtop}});
    foreach my $skey (@skeys) {
      $wuc->set($skey, "on", "off", 1);
    }
     my $wuc2 = $object->image_config_hash( 'aligncompara', 'alignsliceviewbottom' );
     foreach my $sp (grep {/_compara_/}keys %{$wuc2->{user}->{alignsliceviewbottom}}) {
      my ($spe, $ctype) = split(/_compara_/, $sp);
       $spe = ucfirst($spe);
      if (defined($wuc->{general}->{alignsliceviewtop}->{"synteny_$spe"})) {
           $wuc->set("synteny_$spe", "on", "on", 1) if ($wuc2->get($sp, "on") eq 'on');
      }
    }

     my $image    = $object->new_image( $slice, $wuc, $object->highlights );
 
     $image->set_button( 'form',
                      'name'   => 'click',
                       'id'     => 'click_top',
                       'URL'    => "/@{[$object->species]}/@{[$object->script]}",
                       'hidden' => {
          'click_left'        => int( $wuc->transform->{'translatex'} ),
          'click_right'       => int( $wuc->transform->{'scalex'} *
($panel->option('end')-$panel->option('start')+1)
 + int( $wuc->transform->{'translatex'} ) ),
          'seq_region_strand' => $object->seq_region_strand,
          'seq_region_left'   => $panel->option('start'),
          'seq_region_right'  => $panel->option('end'),
          'seq_region_width'  => $object->seq_region_end-$object->seq_region_start + 1,
          'seq_region_name'   => $object->seq_region_name,
          'h'                 => $object->highlights_string,
      }
                       );
    $panel->print( $image->render );
    return 1;
 }


1;    
