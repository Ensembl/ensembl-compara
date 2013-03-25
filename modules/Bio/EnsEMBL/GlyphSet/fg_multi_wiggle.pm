package Bio::EnsEMBL::GlyphSet::fg_multi_wiggle;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_wiggle_and_block);

sub label { return undef; }

sub draw_features {
  my ($self, $wiggle) = @_;
  my $config           = $self->{'config'};  
  my $cell_line        = $self->my_config('cell_line'); 
  my $set              = $self->my_config('set');
  my $label            = $self->my_config('label');
  my $display          = $self->my_config('display');
  my $reg_view         = $config->hub->type eq 'Regulation';
  my $data             = $config->{'data_by_cell_line'}{$cell_line}; 
  my $colours          = $config->{'fg_multi_wiggle_colours'} ||= $self->get_colours;
  my ($peaks, $wiggle) = $display eq 'tiling_feature' ? (1, 1) : $display eq 'compact' ? (1, 0) : (0, 1);
  
  # First draw block features
  if ($peaks) {
    if ($data->{$set}{'block_features'}) {   
      $self->draw_blocks($data->{$set}{'block_features'}, $label, undef, $colours, $data->{$set}{'configured'} ? sprintf '%s/%s features turned on', map scalar @{$data->{$set}{$_}}, qw(configured available) : '');
    } else {
      $self->display_error_message($cell_line, $set, 'peaks');
    }
  }
  
  # Then draw wiggle features
  if ($wiggle) {
    if ($data->{$set}{'wiggle_features'}) {   
      $self->process_wiggle_data($data->{$set}{'wiggle_features'}, $colours, $label, $cell_line, $set, $reg_view);
    } else {
      $self->display_error_message($cell_line, $set, 'wiggle'); 
    }
  } 
  
  return 0;
}

sub draw_blocks { 
  my ($self, $fs_data, $display_label, $bg_colour, $colours, $tracks_on) = @_;
  
  $self->draw_track_name($display_label, 'black', -118, undef);
  
  if ($tracks_on) {
     $self->draw_track_name($tracks_on, 'grey40', -118, 0);
  } else {  
    $self->draw_space_glyph;
  }

  foreach my $f_set (sort { $a cmp $b } keys %$fs_data) { 
    my $feature_name = $f_set; 
    my @temp         = split /:/, $feature_name;
       $feature_name = $temp[1];  
    my $colour       = $colours->{$feature_name};  
    my $features     = $fs_data->{$f_set}; 
    my $label        = $display_label =~ /MultiCell/ ? "$temp[0]:$temp[1]" : $temp[1];
    
    $self->draw_track_name($label, $colour, -108, 0, 'no_offset');
    $self->draw_block_features ($features, $colour, $f_set, 1, 1);
  }

  $self->draw_space_glyph;
}

sub draw_wiggle {
  my ($self, $features, $min_score, $max_score, $colours, $labels) = @_;
  
  $self->draw_wiggle_plot(
    $features, # Features array
    { min_score => $min_score, max_score => $max_score, graph_type => 'line', axis_colour => 'black' },
    $colours,
    $labels
  );
}

sub process_wiggle_data {
  my ($self, $wiggle_data, $colour_keys, $label, $cell_line, $set, $reg_view) = @_; 
  my $config   = $self->{'config'};
  my $max_bins = $self->image_width;
  my @labels   = ($label);
  my ($min_score, $max_score, $data_flag) = (0, 0, 0);
  my (@all_features, $legend, @colours);
  
  foreach my $evidence_type (keys %$wiggle_data) {
    my $result_set = $wiggle_data->{$evidence_type}; 
    my @features   = @{$config->{'data_by_cell_line'}{'wiggle_data'}{$evidence_type}};   
    
    next unless scalar @features > 0;
    
    $data_flag = 1;
    
    my $wsize = $features[0]->window_size; 
    my $start = 1 - $wsize; # Do this here so we minimize the number of calcs done in the loop
    my $end   = 0;

    @features = sort { $a->scores->[0] <=> $b->scores->[0] } @features;
    
    my ($f_min_score, $f_max_score) = sort @{$features[0]->get_min_max_scores};

    if ($wsize == 0) {
      $f_min_score = $features[0]->scores->[0]; 
      $f_max_score = $features[-1]->scores->[0]; 
    } else {
      my @rfs;
      
      foreach my $rf (@features) {
        for (0..$#{$rf->scores}){
          $start += $wsize;
          $end   += $wsize;
          
          push @rfs, { start => $start, end => $end, score => $rf->scores->[$_] };
        }
      }
      
      @features = @rfs;
    }
    
    $min_score = $f_min_score if $f_min_score <= $min_score;
    $max_score = $f_max_score if $f_max_score >= $max_score;

    my $feature_name = $evidence_type;
    my @temp         = split /:/, $feature_name;
       $feature_name = $temp[1];
    my $colour       = $colour_keys->{$feature_name}; 
    
    push @labels, $feature_name;
    push @all_features, \@features;
    push @colours, $colour;
    
    $legend->{$feature_name} = $colour; 
  }

  if ($data_flag == 1) {
    $max_score = 1 if $reg_view && $max_score <= 1;
    
    $self->draw_wiggle(\@all_features, $min_score, $max_score, \@colours, \@labels);
    
    # Add colours to legend
    my $legend_colours       = $self->{'legend'}{'fg_multi_wiggle_legend'}{'colours'} || {};
       $legend_colours->{$_} = $legend->{$_} for keys %$legend;
    
    $self->{'legend'}{'fg_multi_wiggle_legend'} = { priority => 1030, legend => [], colours => $legend_colours };
  } else {
    $self->display_error_message($cell_line, $set, 'wiggle');
  }    
}

sub block_features_zmenu {
  my ($self, $f) = @_;
  my $offset = $self->{'container'}->strand > 0 ? $self->{'container'}->start - 1 :  $self->{'container'}->end + 1;
  
  return $self->_url({
    action => 'FeatureEvidence',
    fdb    => 'funcgen',
    pos    => sprintf('%s:%s-%s', $f->slice->seq_region_name, $offset + $f->start, $f->end + $offset),
    fs     => $f->feature_set->name,
    ps     => $f->summit || 'undetermined',
  });
}

sub get_colours {
  my $self      = shift;
  my $config    = $self->{'config'};
  my $colourmap = $config->colourmap;
  my %ratio     = ( 1 => 0.6, 2 => 0.4, 3 => 0.2, 4 => 0 );
  my $count     = 0;
  my %feature_colours;

  # First generate pool of colours we can draw from
  if (!exists $config->{'pool'}) {
    my $colours = $self->my_config('colours');
    
    $config->{'pool'} = [];
    
    if ($colours) {
      $config->{'pool'}[$_] = $self->my_colour($_) for sort { $a <=> $b } keys %$colours;
    } else {
      $config->{'pool'} = [qw(red blue green purple yellow orange brown black)]
    }
  }
  
  # Assign each feature set a colour, and set the intensity based on methalation state
  foreach my $name (sort keys %{$config->{'data_by_cell_line'}{'colours'}}) { 
    my $histone_pattern = $name;
    
    if (!exists $feature_colours{$name}) {
      my $c = $config->{'pool'}[$count++];
      
      $count = 0 if $count >= 55;
      
      if ($histone_pattern =~ s/^H\d+//) {
        # First assign a colour for most basic pattern - i.e. no methyalation state information
        my $histone_number = substr $name, 0, 2;

        s/me\d+// for $histone_pattern, $name;
        
        $feature_colours{$name} = $colourmap->mix($c, 'white', $ratio{4});

        # Now add each possible methyalation state of this type with the appropriate intensity
        for (my $i = 1; $i <= 4; $i++) {
          $histone_pattern  = $histone_number . $histone_pattern unless $histone_pattern =~ /^H\d/;
          $histone_pattern .= $histone_pattern =~ s/me\d+/me$i/ ? '' : "me$i";
          
          $feature_colours{$histone_pattern} = $colourmap->mix($c, 'white', $ratio{$i});
        }
      } else {
        $feature_colours{$name} = $colourmap->mix($c, 'white', $ratio{4});
      }
    }
  }

  return \%feature_colours;
}

sub display_error_message {
  my ($self, $cell_line, $set, $type) = @_;
  my $config = $self->{'config'}; 
  
  return unless $config->get_option('opt_empty_tracks') == 1; 
  
  $self->draw_track_name(join(' ', $config->hub->get_adaptor('get_FeatureTypeAdaptor', 'funcgen')->get_regulatory_evidence_info($set)->{'label'}, $cell_line), 'black', -118,  2, 1);
  $self->display_no_data_error(sprintf '%s/%s available feature sets turned on', map scalar @{$config->{'data_by_cell_line'}{$cell_line}{$set}{$_}||[]}, qw(configured available));
  
  return 1;
}

1;
