package EnsEMBL::Web::Configuration::MultipleLocation;

use strict;
use EnsEMBL::Web::Configuration::Location;
our @ISA = qw( EnsEMBL::Web::Configuration::Location );
use POSIX qw(floor ceil);


## Function to configure contigview

sub dotterview {
  my $self   = shift;
  my $obj    = $self->{object};

  my @loc    = $obj->Locations;
  if( @loc < 2 ) {
    if( my $error_panel = $self->new_panel( '',
      'code' => 'error', 'caption' => 'DotterView - error',
      'content' => '<p>Error we do not have two slices</p>'
    ) ) {
      $error_panel->add_components(qw(
        error_message EnsEMBL::Web::Component::Dotter::dotter_error
      ));
      $self->add_panel( $error_panel );
    }
    return;
  }
  my $primary_species   = $obj->species_defs->SPECIES_COMMON_NAME;
  my $secondary_species = $obj->species_defs->other_species( $loc[1]->real_species, 'SPECIES_COMMON_NAME' );
  if( my $dotter = $self->new_panel( 'Image',
    'code' => 'dotter_#',
    'caption' => "Dotter for $primary_species vs $secondary_species"
  )) {
    $dotter->add_components(qw(
      image EnsEMBL::Web::Component::Dotter::dotterview
    ));
    $self->add_panel( $dotter );
  }
}

sub multicontigview {
  my $self   = shift;
  my $obj    = $self->{object};
  my $q_hash = $obj->generate_query_hash();
  $self->update_configs_from_parameter( 'bottom', 'thjviewbottom' );
  my $last_rendered_panel = undef;

  if( my $ideo = $self->new_panel( 'Image',
    'code' => "ideo_#", 'caption' => "Top level", 'status'  => "panel_ideogram", 'params' => $q_hash
  ) ) {
    $last_rendered_panel = $ideo if $obj->param('panel_ideogram') ne 'off';
    $ideo->add_components(qw(
      image   EnsEMBL::Web::Component::Location::multi_ideogram
    ));
    $self->add_panel( $ideo );
  }
  if( my $over = $self->new_panel( 'Image',
    'code'    => "top_#", 'caption' => "Navigational overview", 'status' => 'panel_top', 'params' => $q_hash
  ) ) {
    if( $obj->param('panel_top') ne 'off' ) {
      my $counter = 0;
      foreach my $loc ( $obj->Locations ) {
        my $max_length = ($obj->species_defs->other_species( $loc->real_species, 'ENSEMBL_GENOME_SIZE' )||1) * 1.001e6;
        my($start,$end) = $self->top_start_end( $loc, $max_length );
        $last_rendered_panel->add_option( "red_box_$counter", [$start,$end] ) if $last_rendered_panel;
        $over->add_option( "start_$counter", $start );
        $over->add_option( "end_$counter",   $end  );
        $counter++;
      }
      $over->add_option( 'red_edge', 'yes' );
      $last_rendered_panel = $over;
    }
    $over->add_components(qw(
      image   EnsEMBL::Web::Component::Location::multi_top
    ));
    $self->add_panel( $over );
  }
  $self->initialize_zmenu_javascript;
  $self->initialize_ddmenu_javascript;
  if( my $bottom = $self->new_panel( 'Image',
    'code'    => "bottom_#", 'caption' => "Detailed View", 'status' => 'panel_bottom', 'params' => $q_hash
  ) ) {
    if( $obj->param('panel_bottom') ne 'off' ) {
      my $counter = 0;
      foreach my $loc ( $obj->Locations ) {
        $last_rendered_panel->add_option( "red_box_$counter",
          [$loc->seq_region_start,$loc->seq_region_end] ) if $last_rendered_panel;
        $counter++;
      }
      $last_rendered_panel = $bottom;
     $bottom->add_option( 'red_edge', 'yes' );
    }
    $bottom->add_components(qw(
      image_menu  EnsEMBL::Web::Component::Location::multi_bottom_menu
      image_nav   EnsEMBL::Web::Component::Location::multi_bottom_nav
      image       EnsEMBL::Web::Component::Location::multi_bottom
    ));
    $self->{page}->content->add_panel( $bottom );
  }
  return;
    
}

sub context_menu {
  my $self = shift;
  $self->SUPER::context_menu();
  my( $p, @sec ) = $self->{object}->Locations;
  return unless @sec;
  my @options;
  my $flag = "contig$self->{'flag'}";

  #remove 'normal' link to contigview for primary species
  my $menu = $self->{'page'}->menu;
  $menu->delete_entry($flag,'cv_link');

  foreach ( $p, @sec ) {
    (my $HR = $_->real_species ) =~s/_/ /;
	my $srtn = $_->seq_region_type_and_name;
    my $title = "@{[$srtn]} @{[$_->thousandify(floor($_->seq_region_start))]}";
    if( floor($_->seq_region_start) != ceil($_->seq_region_end) ) {
      $title .= " - @{[$_->thousandify(ceil($_->seq_region_end))]}";
    }
    push @options, {
      'text' => "... <em>$HR $srtn </em>", 'raw'=>1,
      'href' => sprintf( "/%s/contigview?c=%s:%s;w=%s", $_->real_species, $_->seq_region_name, $_->centrepoint, $_->length ),
      'title' => "$HR $title"
    };
  }

  #add new link to contigview for primary and secondary slices
  $menu->add_entry_after($flag, 'mv_link', 'code' => 'cv',
					'text' => 'Graphical view of...',
					'title' => 'ContigView - genome browser view of primary and secondary slices', 
					'href' => $options[0]{'href'}, 'options'=> \@options );
}

1;
