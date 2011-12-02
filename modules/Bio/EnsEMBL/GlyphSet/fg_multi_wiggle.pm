package Bio::EnsEMBL::GlyphSet::fg_multi_wiggle;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_wiggle_and_block);
use Bio::EnsEMBL::Utils::Exception qw( throw );

sub label {
  return undef;
}

sub draw_features {
  my ($self, $wiggle) = @_;
  my $Config = $self->{'config'};  
  my $slice = $self->{'container'};
  my $cell_line = $self->my_config('cell_line'); 
  my $object_type = 'Regulation';
  if ($Config->isa('EnsEMBL::Web::ImageConfig::contigviewbottom')){ $object_type = 'Location'; }
  my $type = $self->my_config('type');  
  my $data = $Config->{'data_by_cell_line'}; 
  my $label = $type eq 'core' ? 'TFBS & Dnase1' : 'Hists & Pols';
  if (!$Config->{'colours'}){ $Config->{'colours'} = $self->get_colours; }
  my $colours = $Config->{'colours'};
  my $display_style = $self->my_config('display');
  my ($drawn_data, $peaks, $wiggle);
  
  if ($display_style eq 'compact'){ 
    $peaks = 1;
  } elsif ($display_style eq 'tiling_feature') {
    $peaks =1;
    $wiggle = 1;
  } else {
    $wiggle = 1;
  } 

  # First draw block features
  if ($peaks){
    if ($data->{$cell_line}{$type}{'block_features'} && $peaks){   
      my $tracks_on = undef;
      if ($data->{$cell_line}{$type}{'configured'}){
        my $configured_tracks = scalar @{$data->{$cell_line}{$type}{'configured'}}; 
        my $available_tracks =  scalar @{$data->{$cell_line}{$type}{'available' }}; 
        $tracks_on = "$configured_tracks/$available_tracks features turned on";  
      }
      my $feature_set_data = $Config->{'data_by_cell_line'}{$cell_line}{$type}{'block_features'}; 
      $self->draw_blocks($feature_set_data, "$label $cell_line", undef, $colours, $tracks_on);
      $drawn_data = 1;
    } else {
      $self->display_error_message($cell_line, $type, 'peaks');
    }
  }
  # Then draw wiggle features
  if ($wiggle) { 
    if ($Config->{'data_by_cell_line'}{$cell_line}{$type}{'wiggle_features'} && $wiggle){   
      my %wiggle_data = %{$Config->{'data_by_cell_line'}{$cell_line}{$type}{'wiggle_features'}}; 
      $self->process_wiggle_data(\%wiggle_data, $colours, [ "$label $cell_line" ], $cell_line, $type, $object_type);
      $drawn_data =1;
    } else {
      $self->display_error_message($cell_line, $type, 'wiggle'); 
    }
  } 

  # if we have drawn tracks for this cell line add a separating line    
  if ($drawn_data || $data->{$cell_line}{'reg_feature'} || ($Config->get_option('opt_empty_tracks') == 1)){ 
    # do not draw on contig view
    return if ($object_type eq 'Location');
    unless (exists $data->{$cell_line}->{'last_cell_line'}){
      if ($type eq 'core') { 
        return if $Config->get_node('functional')->get_node('reg_feats_other_'.$cell_line);
      }
      $self->draw_separating_line;
    }
  }

  return;
}

sub draw_blocks { 
  my ($self, $fs_data, $display_label, $bg_colour, $colours, $tracks_on) = @_;
  $self->draw_track_name($display_label, 'black', -118, undef);
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
    my $label  = $temp[1];
    if  ($display_label =~/MultiCell/){ $label = $temp[0].':' .$temp[1];} 
    $self->draw_track_name($label, $colour, -108, 0, 'no_offset');
    $self->draw_block_features ($features, $colour, $f_set, 1, 1);
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
  my ($self, $wiggle_data, $colour_keys, $labels, $cell_line, $type, $object_type) = @_; 
  my $slice = $self->{'container'}; 

  my $max_bins = $self->image_width(); 
  my ($min_score, $max_score) ==  (0, 0);
  my @all_features;
  my $legend;
  my @colours;
  my $data_flag = 0;

  foreach my $evidence_type (keys %{$wiggle_data}){  
    my $result_set =  $wiggle_data->{$evidence_type}; 
    my @features = @{$self->{'config'}{'data_by_cell_line'}{'wiggle_data'}{$evidence_type}};    
    next unless scalar @features >> 0;
    $data_flag = 1;
    my $wsize = $features[0]->window_size; 
    my $start = 1 - $wsize;#Do this here so we minimize the number of calcs done in the loop
    my $end   = 0;
    my $score;

    @features   = sort { $a->scores->[0] <=> $b->scores->[0]  } @features;
    my ($f_min_score, $f_max_score) = sort @{$features[0]->get_min_max_scores()};

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
    $legend->{$feature_name} = $colour; 
  }

  if ($data_flag == 1) {
    if ($object_type eq 'Regulation' && $max_score <= 1) {$max_score = 1;}
    $self->draw_wiggle( \@all_features, $min_score, $max_score, \@colours, $labels );
    #Add colours to legend
    my $legend_colours = $self->{'config'}->{'fg_multi_wiggle_legend'}{'colours'} || {};
    foreach my $feature (keys %$legend ){ 
      $legend_colours->{$feature} = $legend->{$feature};
    } 
    $self->{'config'}->{'fg_multi_wiggle_legend'} = {'priority' => 1030, 'legend' => [], 'colours' => $legend_colours };
  } else {
    $self->display_error_message($cell_line, $type, 'wiggle');
  }    
}

sub block_features_zmenu {
  my ($self, $f) = @_;
  my $offset     = $self->{'container'}->strand > 0 ? $self->{'container'}->start - 1 :  $self->{'container'}->end + 1;
  
  return $self->_url({
    action => 'FeatureEvidence',
    fdb    => 'funcgen',
    pos    => sprintf('%s:%s-%s', $f->slice->seq_region_name, $offset + $f->start, $f->end + $offset),
    fs     => $f->feature_set->name,
    ps     => $f->summit || 'undetermined',
  });
}

sub get_colours {
  my $self = shift;
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
#  my %feature_types = %{$self->{'config'}->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'feature_type'}{'ids'}};
  my %feature_types = %{$self->{'config'}->{'data_by_cell_line'}->{'colours'}};

  my $count = 0;
  foreach my $name (sort keys %feature_types){ 
    #$name =~s/\:\d*//;
    my $histone_pattern = $name;
    unless ( exists $feature_colours{$name}) {  
      my $c =  $self->{'config'}{'pool'}->[$count];  
      $count ++;
      if ($count >= 55){$count = 0}; 
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
  my $number_available = scalar @{$Config->{'data_by_cell_line'}{$cell_line}{$focus}{'available'}};
  my $number_configured  = scalar @{$Config->{'data_by_cell_line'}{$cell_line}{$focus}{'configured'}};
  return unless $Config->get_option('opt_empty_tracks') == 1; 
  my ($class,  $display_style); 
   
  if ($type eq 'peaks'){
    if ($focus eq 'core') {
      $class = 'Evidence';
    } else {
      $focus = 'Hists & Pols';
    }
  } elsif ($type eq 'wiggle') {
    $class = 'Support';
  }  

  my $error_message = "$number_configured/$number_available available feature sets turned on";
  $self->draw_track_name(join(' ', grep $_, ucfirst $focus, $class, $cell_line), 'black', -118,  2, 1);
  $self->display_no_data_error($error_message);
    
  return 1;
}

1;
