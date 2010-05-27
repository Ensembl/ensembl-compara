package Bio::EnsEMBL::GlyphSet::fg_multi_wiggle;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_wiggle_and_block);
use Bio::EnsEMBL::Utils::Exception qw( throw );


sub draw_features {
  my ($self, $wiggle) = @_;
  my $Config = $self->{'config'};
  my $data = $Config->{'data_by_cell_line'};
  my $colours = $self->get_colours($Config->{'evidence'}->{'data'}->{'all_features'});
  my $drawn_wiggle_flag = $wiggle ? 0: "wiggle";
  my $slice = $self->{'container'};
  my $drawn_data;
  
  foreach my $cell_line (keys %$data){   
    # First draw core block features
    if ($data->{$cell_line}{'focus'}{'block_features'}){
      my $configured_tracks = scalar @{$Config->{'configured_tracks'}{$cell_line}{'configured'}{'focus'}};
      my $available_tracks =  scalar @{$Config->{'configured_tracks'}{$cell_line}{'available' }{'focus'}};
      my $tracks_on = "$configured_tracks/$available_tracks features turned on"; 
      my $feature_set_data = $data->{$cell_line}{'focus'}{'block_features'};
      $self->draw_blocks($feature_set_data, 'Core Evidence' . $cell_line, undef, $colours, $tracks_on);
      $drawn_data = 1;
    } else {
       $self->display_error_message($cell_line, 'focus', 'peaks');
    }
    # Then draw core supporting features
    if ($data->{$cell_line}{'focus'}{'wiggle_features'}  && $wiggle){ 
      my %wiggle_data = %{$data->{$cell_line}{'focus'}{'wiggle_features'}};
      my $label = 'Core Support ' .$cell_line;
      my @labels = ($label);
      $self->process_wiggle_data(\%wiggle_data, $colours, \@labels, $cell_line);
      $drawn_data =1;
    } else {
      $self->display_error_message($cell_line, 'focus', 'wiggle');
    }
    # Next draw other block features
    if ($data->{$cell_line}{'non_focus'}{'block_features'}){
      my $configured_tracks = scalar @{$Config->{'configured_tracks'}{$cell_line}{'configured'}{'non_focus'}};
      my $available_tracks =  scalar @{$Config->{'configured_tracks'}{$cell_line}{'available' }{'non_focus'}};
      my $tracks_on = "$configured_tracks/$available_tracks features turned on";
      my $feature_set_data = $data->{$cell_line}{'non_focus'}{'block_features'};
      $self->draw_blocks($feature_set_data, 'Other Evidence for ' . $cell_line, undef, $colours, $tracks_on);
      $drawn_data = 1;
    } else {
      $self->display_error_message($cell_line, 'non_focus', 'peaks');
    }
    # Finally draw supporting sets for other features
    if ($data->{$cell_line}{'non_focus'}{'wiggle_features'}  && $wiggle){
      my %wiggle_data = %{$data->{$cell_line}{'non_focus'}{'wiggle_features'}};
      my $label = 'Support for ' .$cell_line;
      my @labels = ($label);
      $self->process_wiggle_data(\%wiggle_data, $colours, \@labels, $cell_line);
      $drawn_data = 1;
    } else {
       $self->display_error_message($cell_line, 'non_focus', 'wiggle');
    }


    # if we have drawn tracks for this cell line add a separating line    
    if ($drawn_data || $Config->{'reg_feature'} || ($Config->get_parameter('opt_empty_tracks') eq 'yes')){  
      unless (exists $data->{$cell_line}->{'last_cell_line'}){
        $self->draw_separating_line;
      }
    }
  }

  return 1;
}

sub draw_blocks { 
  my ($self, $fs_data, $display_label, $bg_colour, $colours, $tracks_on) = @_;
  $self->draw_track_name($display_label, 'black', -118, 0);
  if ($tracks_on ){
     $self->draw_track_name($tracks_on, 'grey40', -118, 0);
  } else {  
    $self->draw_space_glyph();
  }

  foreach my $f_set (sort { $a cmp $b  } keys %$fs_data){
    my $feature_name = $f_set; 
    my @temp = split (/:/, $feature_name);
    $feature_name = $temp[1];
    my $colour   = $colours->{$feature_name}; 
    my $features = $fs_data->{$f_set};
    my $display_label = $f_set;
    $display_label =~s/\w*\://;
    $self->draw_track_name($display_label, $colour, -108, 0, 'no_offset');
    $self->draw_block_features ($features, $colour, $f_set, 1);
  }
  $self->draw_space_glyph();
}

sub draw_wiggle {
  my ( $self, $features, $min_score, $max_score, $colours, $labels ) = @_;
  $self->draw_wiggle_plot(
    $features,                      ## Features array
    { 'min_score' => $min_score, 'max_score' => $max_score, 'graph_type' => 'line', 'axis_colour' => 'black' },
    $colours,
    $labels
  );
}

sub process_wiggle_data {
  my ($self, $wiggle_data, $colour_keys, $labels, $cell_line) = @_;
  my $slice = $self->{'container'};

  my $max_bins = $self->image_width();
  my ($min_score, $max_score) ==  (0, 0);
  my @all_features;
  my @colours;

  foreach my $evidence_type (keys %{$wiggle_data}){ 
    my $result_set =  $wiggle_data->{$evidence_type};
    my @features = @{$result_set->get_ResultFeatures_by_Slice($slice, undef, undef, $max_bins)};
    my $wsize = $features[0]->window_size;
    my $start = 1 - $wsize;#Do this here so we minimize the number of calcs done in the loop
    my $end   = 0;
    my $score;

    @features   = sort { $a->scores->[0] <=> $b->scores->[0]  } @features;
    my ($f_min_score, $f_max_score) = @{$features[0]->get_min_max_scores()};
    if ($wsize ==0){
      $f_min_score = $features[0]->scores->[0]; 
      $f_max_score = $features[-1]->scores->[0]; 
    } else {
      my @rfs = ();
      foreach my $rf (@features){
        for my $x(0..$#{$rf->scores}){
          $start += $wsize;
          $end += $wsize;
          $score = $rf->scores->[$x];
          my $f = { 'start' => $start, 'end' => $end, 'score' => $score };
          push (@rfs, $f);
        }
      }
      @features = @rfs;
    }
    if ($f_min_score <= $min_score){ $min_score = $f_min_score; }
    if ($f_max_score >= $max_score){ $max_score = $f_max_score; }
    my $feature_name = $evidence_type;
    my @temp = split(/:/, $feature_name);
    $feature_name = $temp[1];
    my $colour = $colour_keys->{$feature_name}; 
    push @$labels, $feature_name;
    push @all_features, \@features;
    push @colours, $colour; 
 }

  if ($max_score <=10){ 
    if ($cell_line =~/IMR90/) {
      unless ($max_score >= 2){
        $max_score =2;
      }
    } else {
      $max_score = 10;
    }
  }  
  $self->draw_wiggle( \@all_features, $min_score, $max_score, \@colours, $labels );
}

sub block_features_zmenu {
  my ($self, $f) = @_;
  my $offset = $self->{'container'}->strand > 0 ? $self->{'container'}->start - 1 :  $self->{'container'}->end + 1;
  my $pos = $f->slice->seq_region_name .":". ($offset + $f->start )."-".($f->end+$offset);
  my $feature_set = $f->feature_set->name;
  my $midpoint = $f->score || 'undetermined'; 
  my $id = $self->{'config'}->core_objects->regulation->stable_id;
  my $href = $self->_url
  ({
    'action'  => 'FeatureEvidence',
    'rf'      => $id,
    'fdb'     => 'funcgen',
    'pos'     => $pos,
    'fs'      => $feature_set,
    'ps'      => $midpoint,
  });

  return $href;
}

sub get_colours {
  my( $self, $f ) = @_;
  my %feature_colours;

  # First generate pool of colours we can draw from
  unless(exists $self->{'config'}{'pool'}) {
    $self->{'config'}{'pool'} = [];
    my $colours = $self->my_config('colours');
    if( $colours ) {
      foreach (sort { $a <=> $b } keys %$colours ) {
        $self->{'config'}{'pool'}[$_] = $self->my_colour( $_ );
      }
    } else {
      $self->{'config'}{'pool'} = [qw(red blue green purple yellow orange brown black)]
    }
  }

  # Assign each feature set a colour, and set the intensity based on methalation state
  my %ratio = ('1' => '0.6', '2' => '0.4', '3' => '0.2', '4' => '0');
  my %feature_types = %{$self->{'config'}->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'feature_type'}{'ids'}};

  foreach my $name ( keys %feature_types){ 
    $name =~s/\:\d*//;
    my $histone_pattern = $name;
    unless ( exists $feature_colours{$name}) { 
      my $c = shift @{$self->{'config'}{'pool'}}; 
      if ($histone_pattern =~/^H\d+/){
        # First assign a colour for most basic pattern - i.e. no methyalation state information
        my $histone_number = substr($name,0,2);
        $histone_pattern =~s/^H\d+//;
        $histone_pattern =~s/me\d+//;
        $name =~s/me\d+//;
        my $r =  $ratio{4};
        my $colour_mix = $self->{'config'}->colourmap->mix($c, 'white', $r);
        $feature_colours{$name} = $colour_mix;

        # Now add each possible methyalation state of this type with the appropriate intensity
        for (my $i =1; $i <= 4; $i++){
          unless ($histone_pattern =~/^H\d/){
            $histone_pattern = $histone_number .$histone_pattern;
          }
          if ($histone_pattern =~/me\d+/){
            $histone_pattern =~s/me\d+/me$i/;
          }
          else {
            $histone_pattern .= 'me'.$i ;
          }

          my $r =  $ratio{$i}; 
          my $colour_mix = $self->{'config'}->colourmap->mix($c, 'white', $r);
          $feature_colours{$histone_pattern} = $colour_mix;
        }
      } else { 
        my $r = $ratio{4};
        my $colour_mix = $self->{'config'}->colourmap->mix($c, 'white', $r);
        $feature_colours{$name} = $colour_mix;
      }
    }
  }

  return \%feature_colours;
}

sub display_error_message {
  my ($self, $cell_line, $focus, $type) = @_;
  my $Config = $self->{'config'};
  my $configured_tracks = $Config->{'configured_tracks'};
   
  my $number_available = scalar @{$configured_tracks->{$cell_line}{'available'}{$focus}};
  my $number_configured  = scalar @{$configured_tracks->{$cell_line}{'configured'}{$focus}};
  return unless $Config->get_parameter('opt_empty_tracks') eq 'yes'; 
   
  # For Peak focus tracks if no data display error message 
  if ($focus eq 'focus'){
    if ($type eq 'peaks'){
      my $error_message = "No core evidence block features from $cell_line in this region. $number_configured/$number_available of the available feature sets are currently turned on";
      $self->draw_track_name('Core Evidence '.$cell_line , 'black', -118, 2, 1);
      $self->display_no_data_error($error_message);
    } elsif($type eq 'wiggle') {
      return if $cell_line eq 'MultiCell'; 
      if ($number_available >= 1){
        my $error_message = "No core evidence supporting set features for $cell_line in this region. $number_configured/$number_available of the available feature sets are currently turned on";
        $self->draw_track_name('Core support '.$cell_line , 'black', -118, 2, 1);
        $self->display_no_data_error($error_message);
      } else {
        # no data
        return;
      }      
    }
  } elsif ($focus eq 'non_focus'){ 
    if ($type eq 'peaks'){  
      if ($number_available >= 1){
        my $error_message = "No evidence from other features for $cell_line in this region. $number_configured/$number_available of the available feature sets are currently turned on";
        $self->draw_track_name('Other Evidence '.$cell_line , 'black', -118, 2, 1);
        $self->display_no_data_error($error_message);
      } else {
        # no data
        return;
      }
    } elsif ($type eq 'wiggle'){
      if ($number_available >= 1){
        my $error_message = "No other evidence supporting set features for $cell_line in this region. $number_configured/$number_available of the available feature sets are currently turned on";
        $self->draw_track_name('Other support '.$cell_line , 'black', -118, 2, 1);
        $self->display_no_data_error($error_message);
      } else {
        # no data 
        return; 
      }
    }
  }

  return 1;
}
1;
