=head1 NAME

EnsEMBL::Web::Component::Location

=head1 SYNOPSIS

Show information about the webserver

=head1 DESCRIPTION

A series of functions used to render server information

=head1 CONTACT

Contact the EnsEMBL development mailing list for info <ensembl-dev@ebi.ac.uk>

=cut

package EnsEMBL::Web::Component::Location;

use EnsEMBL::Web::Component;
use Bio::EnsEMBL::ExternalData::DAS::DASAdaptor;
use Bio::EnsEMBL::ExternalData::DAS::DAS;
use EnsEMBL::Web::ExternalDAS;
our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;
no warnings "uninitialized";

use POSIX qw(floor ceil);

=head2 name

  Arg [panel]:  EnsEMBL::Web::Document::Panel::Information;
  Arg [object]: EnsEMBL::Web::Proxy::Object({Static});
  Description: Add a row to an information panel showing the release version and site type

=cut

sub name {
  my($panel,$object) = @_;
  (my $DATE = $object->species_defs->ARCHIVE_VERSION ) =~ s/(\d+)/ $1/;
  $panel->add_row( 'Site summary', qq(<p>@{[$object->species_defs->ENSEMBL_SITETYPE]} - $DATE</p>) );
  return 1;
}

sub multi_ideogram {
  my( $panel, $object ) = @_;
  my $counter = 0;
  my @species = $object->species_list();
## Start the box containing the image
  $panel->printf(
    qq(<div style="width: %dpx; border: solid 1px %s" class="autocenter bg5">),
    $object->param('image_width'), $panel->option( 'red_edge' ) ? 'red' : 'black'  
  );
  foreach my $loc ( $object->Locations ) {
## Foreach of the "species slices, draw an image of the slice within this box!  
    my $slice = $object->database('core', $loc->real_species )->get_SliceAdaptor()->fetch_by_region(
      $loc->seq_region_type, $loc->seq_region_name, 1, $loc->seq_region_length, 1
    );
    my $wuc = $object->user_config_hash( "chromosome_$counter", "chromosome" );
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
  $panel->printf( qq(<div style="width: %dpx; border: solid 1px %s" class="autocenter bg5">),
                  $object->param('image_width'), $panel->option( 'red_edge' ) ? 'red' : 'black'  );
  my @species = $object->species_list();
  foreach my $loc ( $object->Locations ) {
    my $slice = $object->database( 'core', $loc->real_species )->get_SliceAdaptor()->fetch_by_region(
      $loc->seq_region_type, $loc->seq_region_name, $panel->option( "start_$counter" ), $panel->option( "end_$counter" ), $loc->seq_region_strand
    );
    my $wuc = $object->user_config_hash( "contigviewtop_$counter", "contigviewtop" );
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
       $config->{'previous_species'} = $previous_species;
       $config->{'next_species'}     = $next_species;
       $config->{'slice_id'}         = $i;
       $config->{'other_slices'}     = \@other_slices;
    if( $previous_species && $next_species eq $previous_species ) {
      if( $flags{'match'} ) {
        foreach(qw( BLASTZ_RAW PHUSION_BLASTN BLASTZ_NET BLASTZ_GROUP BLASTZ_RECIP_NET) ) {
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
          foreach(qw( BLASTZ_RAW PHUSION_BLASTN BLASTZ_NET BLASTZ_GROUP BLASTZ_RECIP_NET) ) {
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
          foreach(qw( BLASTZ_RAW PHUSION_BLASTN BLASTZ_NET BLASTZ_GROUP BLASTZ_RECIP_NET) ) {
            my $K = lc($next_species)."_".lc($_)."_match";
            $config->set( $K, "on", "on" );
            $config->set( $K, "str", "r" );
            $config->set( $K, "join", 1 ) if $flags{ 'join_match' };
            $config->set( $K, "compact", $flags{ 'group_match' } ? 0 : 1 );
          }
        }
        if( $flags{'hcr'} ) {
          foreach(qw(PHUSION_BLASTN_TIGHT BLASTZ_NET_TIGHT BLASTZ_GROUP_TIGHT)) {
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
  my $wuc = $loc->user_config_hash( "thjviewbottom_$P", "thjviewbottom" );
     $wuc->set_species(     $loc->real_species );
     $wuc->set_width(       $loc->param('image_width') );
     $wuc->container_width( $loc->length );
     $wuc->mult;
     $wuc->{'multi'}  = 1;
     $wuc->{'compara'} = 'primary';
     $wuc->{'slice_number'}=0;
     $loc->slice->{_config_file_name_} = $loc->real_species;
  push @$array, $loc->slice, $wuc;
}

sub push_secondary {
  my( $array, $loc, $slice_no ) = @_;
  my $P = @$array;
  my $wuc = $loc->user_config_hash( "thjviewbottom_$P", "thjviewbottom" );
     $wuc->set_species(     $loc->real_species );
     $wuc->set_width(       $loc->param('image_width') );
     $wuc->container_width( $loc->length );
     $wuc->mult;
     $wuc->{'multi'}   = 1;
     $wuc->{'compara'} = 'secondary';
     $wuc->{'slice_number'} = $slice_no;
     $loc->slice->{_config_file_name_} = $loc->real_species;
  push @$array, $loc->slice, $wuc;
}

sub ideogram {
  my($panel, $object) = @_;
  my $slice = $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, 1, $object->seq_region_length, 1
  );
  my $wuc = $object->user_config_hash( 'chromosome' );
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

sub red_box {
  my( $config, $start, $end ) = @_;
  $config->set( '_settings', 'draw_red_box',  'yes',  1 );
  $config->set( '_settings', 'red_box_start', $start, 1 );
  $config->set( '_settings', 'red_box_end',   $end,   1 );
  $config->set( 'redbox', 'on',  'on' );
}

sub contigviewtop {
  my($panel, $object) = @_;
  my $scaling = $object->species_defs->ENSEMBL_GENOME_SIZE || 1;

  my $slice = $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, $panel->option('start'), $panel->option('end'), 1
  );
  my $wuc = $object->user_config_hash( 'contigviewtop' );
     $wuc->container_width( $panel->option('end')-$panel->option('start')+1 );
     $wuc->set_width(       $object->param('image_width') );
     $wuc->{'image_frame_colour'} = 'red' if $panel->option( 'red_edge' ) eq 'yes';
  red_box( $wuc, @{$panel->option('red_box')} ) if $panel->option( 'red_box' );
  my $image    = $object->new_image( $slice, $wuc, $object->highlights );
     $image->set_button( 'form',
       'name'   => 'click',
       'extra'  => '_top',
       'id'     => 'click_top',
       'title'  => 'Click to centre display',
       'URL'    => "/@{[$object->species]}/@{[$object->script]}",
       'hidden' => {
         'click_left'        => int( $wuc->transform->{'translatex'} ),
         'click_right'       => int( $wuc->transform->{'scalex'} * ($panel->option('end')-$panel->option('start')+1) + int( $wuc->transform->{'translatex'} ) ),
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

sub cytoview {
  my($panel, $object) = @_;
  my $slice = $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, $object->seq_region_start, $object->seq_region_end, 1
  );
  my $wuc = $object->user_config_hash( 'cytoview' );
     $wuc->container_width( $object->length );
     $wuc->set_width( $object->param('image_width') );
     $wuc->set( '_settings', 'URL',   this_link($object).";bottom=%7Cbump_", 1);
     $wuc->{'image_frame_colour'} = 'red' if $panel->option( 'red_edge' ) eq 'yes';
## Now we need to add the repeats...

  add_repeat_tracks( $object, $wuc );
  add_das_tracks( $object, $wuc );

  $wuc->{_object} = $object;

  my $image = $object->new_image( $slice, $wuc, $object->highlights );
     $image->imagemap = 'yes';
  $panel->print( $image->render );
  return 0;
}

sub contigviewbottom_text {
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

sub add_repeat_tracks {
  my( $object, $wuc ) = @_;
  my @T = ();
  foreach my $type ( keys %{ $object->species_defs->other_species( $object->species, 'REPEAT_TYPES') || {} } ) {
    $type =~ s/\W+/_/g;
    push @T, $type if $wuc->get("managed_repeat_$type",'on') eq 'on';
  }
  $wuc->{'_managers'}{'sub_repeat'} = \@T;
}

sub add_das_tracks {
  my( $object, $wuc ) = @_;
  my @T = ();

  my $ext_das = new EnsEMBL::Web::ExternalDAS( $object );
  my $ds2 = $ext_das->{'data'};
  my (@external_das, @internal_das) = ();

  my %das_list = map {(exists $ds2->{$_}->{'species'} && $ds2->{$_}->{'species'} ne $object->species) ? ():($_,$ds2->{$_}) } keys %$ds2;
  foreach my $source ( sort { $das_list{$a}->{'label'} cmp $das_list{$b}->{'label'} } keys %das_list ) {
      if( $wuc->get("managed_extdas_$source",'on') eq 'on' ) {
	  push @external_das, "managed_extdas_$source";

	  my $adaptor = undef;
	  my $dbname = $das_list{$source};
	  eval {
	      my $URL = $dbname->{'URL'};
	      $URL = "http://$URL" unless $URL =~ /https?:\/\//i;
	      my $stype = $dbname->{'type'} || 'ensembl_location';
	      $adaptor = Bio::EnsEMBL::ExternalData::DAS::DASAdaptor->new(
									  -url   => "$URL/das",
									  -dsn   => $dbname->{'dsn'},
									  -type    => $stype,
									  -mapping => $dbname->{'mapping'} || $stype,
									  -name  => $dbname->{'name'},
									  -ens   => $object->database('core'),
									  -proxy_url => $object->species_defs->ENSEMBL_WWW_PROXY 
									  );
	  };
	  if($@) {
	      warn("DAS error >> $@ <<");
	  } else {
	      $object->database('core')->add_DASFeatureFactory( Bio::EnsEMBL::ExternalData::DAS::DAS->new( $adaptor ) );
	  }
      }
  }

  my $EXT = $object->species_defs->ENSEMBL_INTERNAL_DAS_SOURCES;
  foreach my $source ( sort { $EXT->{$a}->{'label'} cmp $EXT->{$b}->{'label'} }  keys %$EXT ) {
      if ($wuc->get("managed_$source",'on') eq 'on') {
	  push @internal_das, "managed_$source" ;

	  my $adaptor = undef;
	  my $dbname = $EXT->{$source};
	  eval {
	      my $URL = $dbname->{'url'};
	      $URL = "http://$URL" unless $URL =~ /https?:\/\//i;
	      my $stype = $dbname->{'type'} || 'ensembl_location';
	      $adaptor = Bio::EnsEMBL::ExternalData::DAS::DASAdaptor->new(
									  -url   => "$URL/das",
									  -dsn   => $dbname->{'dsn'},
									  -type    => $stype,
									  -mapping => $dbname->{'mapping'} || $stype,
									  -name  => $dbname->{'name'},
									  -ens   => $object->database('core'),
									  -proxy_url => $object->species_defs->ENSEMBL_WWW_PROXY 
									  );
	  };
	  if($@) {
	      warn("DAS error >> $@ <<");
	  } else {
	      $object->database('core')->add_DASFeatureFactory( Bio::EnsEMBL::ExternalData::DAS::DAS->new( $adaptor ) );
	  }
      }

  }

  push @T, @external_das, @internal_das;

  $wuc->{'_managers'}{'das'} = \@T;
}

sub contigviewbottom {
  my($panel, $object) = @_;
  my $scaling = $object->species_defs->ENSEMBL_GENOME_SIZE || 1;
  my $max_length = $scaling * 1e6;
  my $slice = $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, $object->seq_region_start, $object->seq_region_end, 1
  );
  my $wuc = $object->user_config_hash( 'contigviewbottom' );
  $wuc->container_width( $object->length );
  $wuc->set_width(       $object->param('image_width') );
  $wuc->set( '_settings', 'URL',   this_link($object).";bottom=%7Cbump_", 1);
  $wuc->{'image_frame_colour'} = 'red' if $panel->option( 'red_edge' ) eq 'yes';
## Now we need to add the repeats...
  red_box( $wuc, @{$panel->option('red_box')} ) if $panel->option( 'red_box' );

  add_repeat_tracks( $object, $wuc );
  add_das_tracks( $object, $wuc );

  $wuc->{_object} = $object;
  my $image = $object->new_image( $slice, $wuc, $object->highlights );
  $image->imagemap = 'yes';
  $panel->print( $image->render );


  return 0;
}

sub nav_box_frame {
  my( $content, $width ) = @_;
  return sprintf
qq(
<div style="width: %dpx; border: solid 1px black; border-width: 1px 1px 0px 1px; padding: 0px;" class="bg5 print_hide_block autocenter"><div style="padding: 2px; margin: 0px;">
  $content
</div></div>
 ), $width-2;
}

sub cp_link {
  my( $object, $cp, $len, $extra ) = @_;
  return sprintf '/%s/%s?c=%s:%s;w=%s%s%s', $object->species, $object->script, $object->seq_region_name, $cp, $len, $extra;
}

sub this_link_offset {
  my( $object, $offset, $extra ) = @_;
  return cp_link( $object, $object->centrepoint + $offset, $object->length, $extra );
}

sub this_link {
  my( $object, $extra ) = @_;
  return cp_link( $object, $object->centrepoint, $object->length, $extra );
}

sub this_link_scale {
  my( $object, $scale, $extra ) = @_;
  return cp_link( $object, $object->centrepoint, $scale, $extra );
}


sub multi_species_list { 
  my( $object,$species ) = @_;
  $species ||= $object->species;
  my %species_flag = ( $species => 1 );
  my %species_hash = ();
  my $C = 1;
  foreach( $object->species_list() ) {
    next if $species_flag{$_};
    $species_flag{ $_       } = 1;
    $species_hash{ 's'.$C++ } = $object->species_defs->ENSEMBL_SHORTEST_ALIAS->{$_};
  }
  return %species_hash;
}

sub contigviewbottom_nav { return bottom_nav( @_, 'contigviewbottom', {} ); }
sub multi_bottom_nav     { return bottom_nav( @_, 'thjviewbottom' , { multi_species_list( $_[1] ) } ); }
sub cytoview_nav         { return bottom_nav( @_, 'cytoview', {} ); }
sub alignsliceviewbottom_nav { return bottom_nav( @_, 'alignsliceviewbottom' , { } ); }

sub ldview_nav           { 
  return bottom_nav( @_, 'ldview',   {
    'snp'    => $_[1]->param('snp')    || undef,
    'gene'   => $_[1]->param('gene')   || undef,
    'pop'    => $_[1]->current_pop_id  || undef,
   # 'w'      => $_[1]->param('w')      || undef,
   # 'c'      => $_[1]->param('c')      || undef,
    'source' => $_[1]->param('source') || "dbSNP",
    'h'      => $_[1]->highlights_string || undef,
  } );	
}

sub bottom_nav {
  my( $panel, $object, $configname, $additional_hidden_values ) = @_;
  my $wuc   = $object->user_config_hash( $configname );
  my $width = $object->param('image_width');

  my $bands = $wuc->get('_settings','show_bands_nav') ne 'yes' ? 0 :
              $object->species_defs->get_table_size( { -db => 'ENSEMBL_DB', -table => 'karyotype' }, $object->species );
  
  $additional_hidden_values->{'h'} = $object->highlights_string;
  
  my $hidden_fields_string = '';
  my $hidden_fields_URL    = '';
  foreach( keys %$additional_hidden_values ) {
    next if $additional_hidden_values->{$_} eq ''; 
    $hidden_fields_string .= qq(<input type="hidden" name="$_" value="$additional_hidden_values->{$_}" />);
    $hidden_fields_URL    .= qq(;$_=$additional_hidden_values->{$_});
  }

  my $SIZE  = $bands ? 8 : 10;
  my $FORM_LINE = qq(<form action="/@{[$object->species]}/@{[$object->script]}" method="get">);
  my $REFRESH   = qq(<input type="submit" class="red-button" value="Refresh" />); 
  my $output = '';
## First of all the dial in box....
  $output .= $FORM_LINE unless $bands;
  $output .=qq(<table style="border:0; margin:0; padding: 0; width: @{[$width-12]}px"><tr valign="middle"><td align="left">);
  $output .= $FORM_LINE if $bands;
  $output .= qq(
    Jump to region <input type="text" name="region" value="@{[$object->seq_region_name]}" size="6" />:
    <input type="text" name="vc_start" size="$SIZE" maxlength="11" value="@{[floor($object->seq_region_start)]}" />-<input type="text" name="vc_end"   size="$SIZE" maxlength="11" value="@{[ceil($object->seq_region_end)]}" />$hidden_fields_string
  );
  $output .= "$REFRESH</form>" if $bands;
  $output .= qq(</td><td align="right">);
  if( $bands ) {
    $output .= qq(
      $FORM_LINE
    Band: <input type="hidden" name="region" value="@{[$object->seq_region_name]}" />
    <input type="text" name="band" size="8" maxlength="11" value="@{[$object->param('band')]}" />
    $hidden_fields_string
    $REFRESH
      </form>
    );
  } else { 
    $output .= $REFRESH;
  }
  $output .= qq(</td></tr></table>);
  $output .= qq(</form>) unless $bands;
## Now the buttons...
  my %zoomgifs = %{$wuc->get('_settings','zoom_gifs')||{}};
  my $scaling = $object->species_defs->ENSEMBL_GENOME_SIZE || 1;
  foreach (keys %zoomgifs) {
    $zoomgifs{$_} = sprintf "%d", sprintf("%.1g",$zoomgifs{$_}*$scaling);
  }
  my %nav_options = map { ($_,1) } @{ $wuc->get('_settings','navigation_options')||[]};  
  my $wid             = $object->length;
  my $length          = $object->seq_region_length;

  my $selected;
  my $zoom_HTML = '';
  my $zoom_HTML_2 = '';
  my @zoomgif_keys = sort keys %zoomgifs;
  my $lastkey = $zoomgif_keys[-1];
  for my $zoom (@zoomgif_keys) {
    my $zoombp = $zoomgifs{$zoom};
    if ( ($wid <= ($zoombp+2) || $zoom eq $lastkey )&& !$selected ){
      $zoom .= "on";
      $selected = "1";
    }
    my $zoomurl = this_link_scale( $object, $zoombp, $hidden_fields_URL );
    my $unit_str = $zoombp;
    if( $zoom lt 'zoom5' ) {
      $zoom_HTML_2 .=qq(<a href="$zoomurl"><img src="/img/buttons/${zoom}.gif" alt="show $unit_str in detail" class="cv-zoom-2" /></a>);
    } else {
      $zoom_HTML .=qq(<a href="$zoomurl"><img src="/img/buttons/${zoom}.gif" alt="show $unit_str in detail" class="cv-zoom" /></a>);
    }
  }
  $zoom_HTML = qq(<table cellspacing="0" class="zoom">
    <tr><td>Zoom</td><td rowspan="2" style="text-align:left">$zoom_HTML</td></tr>
    <tr><td style="text-align:right">$zoom_HTML_2</td></tr>
  </table>);
  
  $output .= qq(<table style="border:0; margin:0; padding: 0; width: @{[$width-12]}px">\n  <tr>\n    <td class="middle">);
############ Left 5mb/2mb/1mb/window
  $output.= sprintf(qq(<a href="%s" class="cv-button">&lt;&lt; 5MB</a>), this_link_offset( $object, -5e6, $hidden_fields_URL ) )
    if exists $nav_options{'5mb'} && $length > 5e6;
  $output.= sprintf(qq(<a href="%s" class="cv-button">&lt; 2MB</a>),     this_link_offset( $object, -2e6, $hidden_fields_URL ) )
    if exists $nav_options{'2mb'} && $length > 2e6;
  $output.= sprintf(qq(<a href="%s" class="cv-button">&lt; 1MB</a>),     this_link_offset( $object, -1e6, $hidden_fields_URL ) )
    if exists $nav_options{'1mb'} && $length > 1e6;
  $output.= sprintf(qq(<a href="%s" class="cv-button">&lt; 500k</a>),     this_link_offset( $object, -5e5, $hidden_fields_URL ) )
    if exists $nav_options{'500k'} && $length > 5e5;
  $output.= sprintf(qq(<a href="%s" class="cv-button">&lt; 200k</a>),     this_link_offset( $object, -2e5, $hidden_fields_URL ) )
    if exists $nav_options{'200k'} && $length > 2e5;
  $output.= sprintf(qq(<a href="%s" class="cv-button">&lt; 100k</a>),     this_link_offset( $object, -1e5, $hidden_fields_URL ) )
    if exists $nav_options{'100k'} && $length > 1e5;
  $output.= sprintf(qq(<a href="%s" class="cv-button">&lt; Window</a>),  this_link_offset( $object, -0.8 * $wid, $hidden_fields_URL ) )
    if exists $nav_options{'window'};
############ Zoom in.....Zoom out
  $output.= qq(</td>\n    <td class="center middle">);
  $output.= sprintf(qq(<a href="%s" class="cv_plusminus">+</a>),         this_link_scale( $object, int( $wid / 2), $hidden_fields_URL ) )
    if exists $nav_options{'half'};
  $output.= qq(${zoom_HTML}) if exists $nav_options{'zoom'};
  $output.= sprintf(qq(<a href="%s" class="cv_plusminus">&#8211;</a>),   this_link_scale( $object, int( $wid * 2), $hidden_fields_URL ) )
    if exists $nav_options{'half'};
############ Right 5mb/2mb/1mb/window
  $output.= qq(</td>\n    <td class="right middle">);
  $output.= sprintf(qq(<a href="%s" class="cv-button">Window &gt;</a>),  this_link_offset( $object, 0.8 * $wid, $hidden_fields_URL ) )
    if exists $nav_options{'window'};
  $output.= sprintf(qq(<a href="%s" class="cv-button">100k &gt;</a>),     this_link_offset( $object, 1e5, $hidden_fields_URL ) )
    if exists $nav_options{'100k'} && $length > 1e5;
  $output.= sprintf(qq(<a href="%s" class="cv-button">200k &gt;</a>),     this_link_offset( $object, 2e5, $hidden_fields_URL ) )
    if exists $nav_options{'200k'} && $length > 2e5;
  $output.= sprintf(qq(<a href="%s" class="cv-button">500k &gt;</a>),     this_link_offset( $object, 5e5, $hidden_fields_URL ) )
    if exists $nav_options{'500k'} && $length > 5e5;
  $output.= sprintf(qq(<a href="%s" class="cv-button">1MB &gt;</a>),     this_link_offset( $object, 1e6, $hidden_fields_URL ) )
    if exists $nav_options{'1mb'} && $length > 1e6;
  $output.= sprintf(qq(<a href="%s" class="cv-button">2MB &gt;</a>),     this_link_offset( $object, 2e6, $hidden_fields_URL ) )
    if exists $nav_options{'2mb'} && $length > 2e6;
  $output.= sprintf(qq(<a href="%s" class="cv-button">5MB &gt;&gt;</a>), this_link_offset( $object, 5e6, $hidden_fields_URL ) )
    if exists $nav_options{'5mb'} && $length > 5e6;
  $output.= qq(</td>\n  </tr>\n</table>);

  $panel->print( nav_box_frame( $output, $width ) );
  return 0;
}

sub cytoview_menu {          return bottom_menu( @_, 'cytoview' ); }
sub contigviewbottom_menu {  return bottom_menu( @_, 'contigviewbottom' ); }

sub bottom_menu {
  my($panel, $object, $configname ) = @_;
  my $mc = $object->new_menu_container(
    'configname' => $configname,
    'panel'      => 'bottom',
    'leftmenus'  => [qw(Features Compara DAS Repeats Options Export ImageSize)],
    'rightmenus' => [qw(Help)],
  );
  $panel->print( $mc->render_html );
  $panel->print( $mc->render_js );
  return 0;
}

sub alignsliceviewbottom_menu {  
    my($panel, $object ) = @_;
    my $configname = 'alignsliceviewbottom';

    my @menu_items = qw(Features AlignCompara Options THExport ImageSize);
    my $mc = $object->new_menu_container(
					 'configname' => $configname,
					 'panel'      => 'bottom',
					 'leftmenus'  => \@menu_items,
					 'rightmenus' => [qw(Help)],
					 );
    $panel->print( $mc->render_html );
    $panel->print( $mc->render_js );
    return 0;
}

sub multi_bottom_menu {
  my($panel, $object ) = @_;
  my( $primary, @secondary ) = ($object->Locations);
  
  my @configs = ();
  my $T = $object->user_config_hash( 'thjviewbottom' );
  $T->{'multi'}=1;
  $T->set_species( $primary->real_species );
  foreach( @secondary ) {
    my $T = $_->user_config_hash( "THJ_".$_->real_species, 'thjviewbottom' );
    $T->mult;
    $T->set_species( $_->real_species );
    push @configs, $T;
  }
  my $mc = $object->new_menu_container(
    'configname' => 'thjviewbottom',
    'panel'      => 'bottom',
    'configs'    => \@configs,
    'leftmenus'  => [qw(Features Compara Repeats Options THExport ImageSize)],
    'rightmenus' => [qw(Help)]
  );
  $panel->print( $mc->render_html );
  $panel->print( $mc->render_js );
  return 0;
}

sub contigviewzoom_nav {
  my($panel, $object) = @_;
  my $wid = $panel->option('end') - $panel->option('start') + 1;
  my %additional_hidden_values = ( 'h' => $object->highlights_string );
  my $hidden_fields_string = join '', map { qq(<input type="input" name="$_" value="$additional_hidden_values{$_}" />) } keys %additional_hidden_values;
  my $hidden_fields_URL    = join '', map { qq(;$_=$additional_hidden_values{$_}) } keys %additional_hidden_values;

  my $zoom_ii = this_link( $object, ';zoom_width='.int($wid*2).$hidden_fields_URL );
  my $zoom_h  = this_link( $object, ';zoom_width='.int($wid/2).$hidden_fields_URL );
  my $pan_left_1_win  = this_link_offset( $object, -0.8 * $wid, $hidden_fields_URL );
  my $pan_right_1_win = this_link_offset( $object,  0.8 * $wid, $hidden_fields_URL );

  my $wuc = $object->user_config_hash( 'contigviewzoom', 'contigviewbottom' );
  my $selected;
  my $width = $object->param('image_width');
  my %zoomgifs = %{$wuc->get('_settings','zoom_zoom_gifs')||{}};
  my $zoom_HTML;
  for my $zoom (sort keys %zoomgifs){
    my $zoombp = $zoomgifs{$zoom};
    if( ($wid <= ($zoombp+2) || $zoom eq 'zoom6' )&& !$selected ){
      $zoom .= "on";
      $selected = "1";
    }
    my $zoomurl =  this_link( $object, ";zoom_width=$zoombp$hidden_fields_URL" );
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

sub contigviewzoom {
  my($panel, $object) = @_;
  my $slice = $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, $panel->option('start'), $panel->option('end'), 1
  );
  my $wuc = $object->user_config_hash( 'contigviewzoom', 'contigviewbottom' );
     $wuc->container_width( $panel->option('end') - $panel->option('start') + 1 );
     $wuc->set_width( $object->param('image_width') );
     $wuc->set( '_settings', 'opt_empty_tracks', 'off' );
     $wuc->set( 'sequence', 'on', 'on' );
     $wuc->set( 'codonseq', 'on', 'on' );
     $wuc->set( 'stranded_contig', 'navigation', 'off' );
     $wuc->set( 'scalebar', 'navigation', 'zoom' );
     $wuc->set( 'restrict', 'on', 'on' ) if $wuc->get( '_settings', 'opt_restrict_zoom' );
     $wuc->set( 'missing', 'on', 'off' );
     $wuc->{'image_frame_colour'} = 'red' if $panel->option( 'red_edge' ) eq 'yes';
     $wuc->set( '_settings', 'URL',   this_link($object).";bottom=%7Cbump_", 1);
## Now we need to add the repeats...

  add_repeat_tracks( $object, $wuc );
  add_das_tracks( $object, $wuc );

  $wuc->{_object} = $object;

  my $image    = $object->new_image( $slice, $wuc, $object->highlights );
  $image->imagemap = 'yes';
  my $T = $image->render;
  $panel->print( $T );
  return 1;
}

sub misc_set {
  my( $panel, $object ) =@_;
  $panel->print( $panel->form( 'misc_set' )->render );
  return 1;
}

sub misc_set_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'misc_set', "/@{[$object->species]}/miscsetview", 'get' );
  my $formats = [
    { 'value' =>'HTML' , 'name' => 'HTML' },
    { 'value' =>'Text' , 'name' => 'Text (Tab separated values)' },
  ];

  my $miscsets;
  if( $object->species eq 'Homo_sapiens' ) {
    $miscsets = [
      { 'value' => 'tilepath'     , 'name' => 'Tile path clones' },
      { 'value' => 'cloneset_1mb' , 'name' => '1mb clone set'    },
      { 'value' => 'cloneset_37k' , 'name' => '37k clone set'    },
      { 'value' => 'cloneset_32k' , 'name' => '32k clone set'    }
    ];
  } elsif( $ENV{'ENSEMBL_SPECIES'} eq 'Mus_musculus' ) {
    $miscsets = [
      { 'value' => 'acc_bac_map' , 'name' => 'Accessioned clones' },
      { 'value' => 'bac_map'     , 'name' => 'BAC clones'         },
      { 'value' => 'cloneset'    , 'name' => '1mb clone set'      },
      { 'value' => 'fosmid_map'    , 'name' => 'Fosmid map'      },
    ];
  }

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
     my $wuc = $object->user_config_hash( 'alignsliceviewbottom' );
     $wuc->container_width( $object->length );
     $wuc->set_width(       $object->param('image_width') );
     $wuc->set( '_settings', 'URL',   this_link($object).";bottom=%7Cbump_", 1);
     $wuc->{'image_frame_colour'} = 'red' if $panel->option( 'red_edge' ) eq 'yes';
 ## Now we need to add the repeats...
     red_box( $wuc, @{$panel->option('red_box')} ) if $panel->option( 'red_box' );
     my $zwa = $object->param('zoom_width');

     my $species = $ENV{ENSEMBL_SPECIES};
     my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, "core", "Slice");
     my $query_slice= $query_slice_adaptor->fetch_by_region("chromosome", $slice->seq_region_name, $slice->start, $slice->end);
     my @sarray = ($ENV{ENSEMBL_SPECIES});

     my ($spe, $type) = split('_compara_', $wuc->get('align_species',$ENV{ENSEMBL_SPECIES} ));
     push (@sarray, ucfirst($spe)) if $spe;

     my $comparadb= &compara_db(); 
     my $mlss_adaptor = $comparadb->get_adaptor("MethodLinkSpeciesSet");
 #    warn("SA: @sarray");

 #    my $method_link_species_set = $mlss_adaptor->fetch_by_method_link_type_registry_aliases("MAVID", \@sarray);
     my $method_link_species_set = $mlss_adaptor->fetch_by_method_link_type_registry_aliases("BLASTZ_NET", \@sarray);

     my $asa = $comparadb->get_adaptor("AlignSlice" );
     my $align_slice = $asa->fetch_by_Slice_MethodLinkSpeciesSet($query_slice, $method_link_species_set, "expanded" );
 #    warn("AS: $align_slice : ".join('*', sort keys(%$align_slice)));

     my @ARRAY;
     my $url = $wuc->get('_settings','URL');
     my $cmpstr = 'primary';
     my $t1 = $wuc->get('ensembl_transcript','compact');

     foreach my $vsp (@sarray) {
       warn("SP :$vsp");
       my $CONF = $object->user_config_hash( 'alignsliceviewbottom' );
       $CONF->{'align_slice'}  = 1;
 #     (my $vsp = $sp) =~ s/\s/\_/g;
       (my $sp = $vsp) =~ s/\_/ /g;
       $CONF->set('scalebar', 'label', $vsp);
       $CONF->set_species($vsp);
       $align_slice->{slices}->{$sp}->{_config_file_name_} = $vsp;
       $CONF->set( 'sequence', 'on', 'on' );
       $align_slice->{slices}->{$sp}->{__type__} = 'alignslice';
       my $cigar_line = $align_slice->{slices}->{$sp}->get_cigar_line();

       $CONF->set('_settings','URL',$url,1);
       $CONF->set('ensembl_transcript', 'compact', $t1, 1);
      my $len = $align_slice->{slices}->{$sp}->length;
       $CONF->container_width( $len );
       $align_slice->{slices}->{$sp}->{species} = $sp;
       $align_slice->{slices}->{$sp}->{compara} = $cmpstr;
       push @ARRAY, $align_slice->{slices}->{$sp}, $CONF;
       $cmpstr = 'secondary';
     }

     $wuc->{_object} = $object;
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

     my $zoom_ii = this_link( $object, ';zoom_width='.($wid-25), $hidden_fields_URL );
     my $zoom_h  = this_link( $object, ';zoom_width='.($wid+25), $hidden_fields_URL );
     my $pan_left_1_win  = this_link_offset( $object, -0.8 * $wid );
     my $pan_right_1_win = this_link_offset( $object,  0.8 * $wid );

     my $wuc = $object->user_config_hash( 'alignsliceviewzoom', 'alignsliceviewbottom' );
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
     my $slice = $object->database('core')->get_SliceAdaptor()->fetch_by_region(
     $object->seq_region_type, $object->seq_region_name, $panel->option('start'), $panel->option('end'), 1
                                                                              );
     my $species = $ENV{ENSEMBL_SPECIES};
     my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, "core", "Slice");
     my $query_slice= $query_slice_adaptor->fetch_by_region("chromosome", $slice->seq_region_name, $slice->start, $slice->end);
     my @sarray = ($ENV{ENSEMBL_SPECIES});

     my $wuc2 = $object->user_config_hash( 'alignsliceviewbottom' );

     my ($spe, $type) = split('_compara_', $wuc2->get('align_species',$ENV{ENSEMBL_SPECIES} ));
     push (@sarray, ucfirst($spe)) if $spe;

     my $comparadb= &compara_db(); 
     my $mlss_adaptor = $comparadb->get_adaptor("MethodLinkSpeciesSet");
     warn("SA: @sarray");

 #    my $method_link_species_set = $mlss_adaptor->fetch_by_method_link_type_registry_aliases("MAVID", \@sarray);
     my $method_link_species_set = $mlss_adaptor->fetch_by_method_link_type_registry_aliases("BLASTZ_NET", \@sarray);

     my $asa = $comparadb->get_adaptor("AlignSlice" );
     my $align_slice = $asa->fetch_by_Slice_MethodLinkSpeciesSet($query_slice, $method_link_species_set, "expanded" );
 #    warn("AS: $align_slice : ".join('*', sort keys(%$align_slice)));

     my @ARRAY;
     my $cmpstr = 'primary';
     (my $psp =  $ENV{ENSEMBL_SPECIES} ) =~ s/\_/ /g;
     my @species = ($psp, grep { $_ ne $psp } keys(%{$align_slice->{slices}}));

     my @SEQ = ();
     foreach my $sp (@species) {
       my $seq = $align_slice->{slices}->{$sp}->seq();

       my $ind = 0;
       foreach (split(//, $seq)) {
           $SEQ[$ind++]->{uc($_)} ++;
       }
     }

     my $num = scalar(@species);

     foreach my $nt (@SEQ) {
       $nt->{S} = join('', grep {$nt->{$_} >= $num} keys(%{$nt}));
     }

     foreach my $sp (@species) {
       my $wuc = $object->user_config_hash( 'alignsliceviewzoom', 'alignsliceviewbottom' );
       $wuc->container_width( $panel->option('end') - $panel->option('start') + 1 );
       $wuc->set_width( $object->param('image_width') );
       $wuc->set( '_settings', 'opt_empty_tracks', 'off' );
       $wuc->set( 'sequence', 'on', 'off' );
       $wuc->set( 'codonseq', 'on', 'off' );
       $wuc->set( 'stranded_contig', 'navigation', 'off' );
       $wuc->set( 'stranded_contig', 'on', 'off' );
       $wuc->set( 'contig', 'on', 'off' );
       $wuc->set( 'scalebar', 'navigation', 'zoom' );
       $wuc->set( 'restrict', 'on', 'off' );
       $wuc->set( 'missing', 'on', 'off' );
       $wuc->set( 'ensembl_transcript', 'on', 'off' );
       $wuc->set( 'evega_transcript', 'on', 'off' );

       $wuc->set( 'ruler', 'on', 'off' );
       $wuc->set( 'scalebar', 'on', 'off' );
       $wuc->set( 'alignscalebar', 'on', 'off' );
       $wuc->set( 'blast_new', 'on', 'off' );

       $wuc->set( 'est_transcript', 'on', 'off' );
       $wuc->{'image_frame_colour'} = 'red' if $panel->option( 'red_edge' ) eq 'yes';
       $wuc->set( '_settings', 'URL',   this_link($object).";bottom=%7Cbump_", 1);
 ## Now we need to add the repeats...
       $wuc->set( 'ensembl_transcript', 'on', 'off');
       $wuc->set( 'navigation', 'on', 'off');

       $wuc->set( '_settings', 'intercontainer', 0, 1 );
       $wuc->set( 'alignment', 'on', 'on' );
       $wuc->set( 'alignscalebar', 'on', 'off' );
       $wuc->set( 'variation', 'on', 'off' );
       $wuc->{_object} = $object;
       $wuc->{'compara'}      = $cmpstr;
       $wuc->{'align_slice'}  = 1;
       (my $vsp = $sp) =~ s/\s/\_/g;
       $wuc->set('scalebar', 'label', $vsp);
       $wuc->set_species($vsp);

       $align_slice->{slices}->{$sp}->{_config_file_name_} = $vsp;
       $align_slice->{slices}->{$sp}->{__type__} = 'alignslice';
       $align_slice->{slices}->{$sp}->{alignmatch} = \@SEQ;
       $align_slice->{slices}->{$sp}->{exons_markup} = &exons_markup($align_slice->{slices}->{$sp});
       $align_slice->{slices}->{$sp}->{snps_markup} = &snps_markup($align_slice->{slices}->{$sp});
       $align_slice->{slices}->{$sp}->{species} = $sp;

       push @ARRAY, $align_slice->{slices}->{$sp}, $wuc;
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
   my @analyses = ( 'ensembl', 'pseudogene');
   my $db_alias = 'core';
   my @genes;
   foreach my $analysis( @analyses ){
 #      foreach my $s (@{$slice->get_all_Slices}) {
 #       push @genes, @{ $s->get_all_Genes( $analysis, $db_alias, 1 ) };
         push @genes, @{ $slice->get_all_Genes() };
#      }
   }

   my @exons;
   foreach (@genes) {
       my $tlist = $_->get_all_Transcripts();
       foreach my $t (@$tlist) {
         my $elist = $t->get_all_Exons();
         foreach my $ex (@$elist) {
             next if (!$ex->start);
 #           warn("EXON:$ex:".join('*', $ex->start, $ex->end, $ex->get_aligned_start, $ex->get_aligned_end, $ex->exon->start, $ex->exon->end)); 
             my ($active_start, $active_end)  = (0, 0);
             if ($ex->exon->end - $ex->exon->start + 1  == $ex->get_aligned_end ) {
                 $active_end = 1;
             }
             if ($ex->get_aligned_start == 1) {
                 $active_start = 1;
             }

             if ($_->strand < 0) {
                 ($active_start, $active_end) = ($active_end, $active_start);
             }

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
     use Data::Dumper;
 #    warn(Dumper($vf_ref));


     foreach (@$vf_ref) {
 #     warn ("KEYS: ".join('*', keys %{$_}));
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
           }
    }

     return \@snps;

 }
 sub alignsliceviewtop {
     my($panel, $object) = @_;
     my $scaling = $object->species_defs->ENSEMBL_GENOME_SIZE || 1;

     my $slice = $object->database('core')->get_SliceAdaptor()->fetch_by_region(
     $object->seq_region_type, $object->seq_region_name, $panel->option('start'), $panel->option('end'), 1
                                                                              );
     my $wuc = $object->user_config_hash( 'alignsliceviewtop' );
     $wuc->container_width( $panel->option('end')-$panel->option('start')+1 );
     $wuc->set_width(       $object->param('image_width') );
     $wuc->{'image_frame_colour'} = 'red' if $panel->option( 'red_edge' ) eq 'yes';
     red_box( $wuc, @{$panel->option('red_box')} ) if $panel->option( 'red_box' );

    my @skeys = grep { $_ =~ /^synteny_/ } keys (%{$wuc->{general}->{alignsliceviewtop}});
    foreach my $skey (@skeys) {
      $wuc->set($skey, "on", "off", 1);
    }
     my $wuc2 = $object->user_config_hash( 'aligncompara', 'alignsliceviewbottom' );
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
          'click_right'       => int( $wuc->transform->{'scalex'} * $object->seq_region_length + int( $wuc->transform->{'translatex'} ) ),
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

sub compara_db {

    #    my $host = 'ia64g';
    #    my $user = 'ensro';
    #    my $dbname = 'abel_mavid_test2';
    #    my $port = 3306;
    
    my $host = 'ecs3d';
    my $user = 'ensro';
    my $dbname = 'ensembl_compara_32';
    my $port = 3307;
# For now just return a new db adaptor, later we can cache it .. 
    return new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (-host => $host, -user => $user, -dbname => $dbname, -port=>$port);
}

1;    
